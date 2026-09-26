# Python client

[![CI](https://github.com/diavasis/diavasi-python/actions/workflows/ci.yml/badge.svg)](https://github.com/diavasis/diavasi-python/actions/workflows/ci.yml)
[![PyPI](https://img.shields.io/pypi/v/diavasi-data.svg)](https://pypi.org/project/diavasi-data/)
[![Python](https://img.shields.io/pypi/pyversions/diavasi-data.svg)](https://pypi.org/project/diavasi-data/)
[![license](https://img.shields.io/github/license/diavasis/diavasi-python)](https://github.com/diavasis/diavasi-python/blob/main/LICENSE)

`diavasi_data.consume` is a thin client of `diavasi.data.v1`. It opens a TLS stream, sends the bearer token, Hello version 1, then JoinGroup. The iterator yields each batch. Continuing the iterator acks that `batch_id`. The client stores no cursor and does not dedupe on `record_id`. A dropped stream is how unacked batches return. Reconnect with the same `consumer_id` and the server replays them.

`proto/data.proto` in this repository is the copy of `diavasi.data.v1` from [github.com/diavasis/diavasi](https://github.com/diavasis/diavasi) tag `v0.12.0`. Package `diavasi-data` is version 0.1.0.

## Install

```bash
pip install diavasi-data==0.1.0
```

From a checkout of this repository:

```bash
python -m venv .venv
.venv/bin/pip install -r requirements.txt
export PYTHONPATH=.
```

## Library

```python
from diavasi_data import CallError, ProtocolError, consume

try:
    for batch in consume(
        addr="127.0.0.1:7710",
        ca="/tmp/diavasi-sdk/dataplane-ca.crt",
        token="sdk-demo",
        group_id="demo",
        consumer_id="python",
        expect_records=8,
    ):
        for record in batch.records:
            print(f"batch {batch.batch_id} record {record.record_id} ({len(record.payload)} bytes)")
except ProtocolError as err:
    print(f"protocol {err.code}: {err.message}")
except CallError as err:
    print(f"grpc {err.status}: {err.message}")
```

The same program is `examples/process.py`. From the repo root, after the server and the `demo` group are up:

```bash
PYTHONPATH=. .venv/bin/python examples/process.py
```

`consume()` acks in a `finally` around the yield, so breaking out of the loop still acks the current batch. `expect_records` sends Leave once that many records are acked. `halt_after_acks` closes after that many acks and does not send Leave. `Session` is the same stream when the caller wants to call `ack` itself.

`ProtocolError` carries the protocol code. `CallError` carries a gRPC status. A bad token raises `CallError` with status `UNAUTHENTICATED` and message `unauthorized`. A group that is not running raises `ProtocolError` with code 5.

| Code | Meaning |
| --- | --- |
| 1 | Bad version |
| 2 | Bad state |
| 3 | Unknown ack |
| 4 | Duplicate ack |
| 5 | Group is not running |
| 6 | Unsupported |
| 7 | Internal |
| 8 | Heartbeat timeout |

## Example

```bash
PYTHONPATH=. python -m diavasi_data \
  --addr 127.0.0.1:7710 --ca /tmp/diavasi-sdk/dataplane-ca.crt \
  --token sdk-demo --group demo --consumer python --total 8
```

Flags: `--addr`, `--ca`, `--token`, `--group`, `--consumer`, `--total`, `--max-in-flight` (default 1), `--halt-after`. The last occurrence of a flag wins. The example prints `record_ids` and `batch_ids`.

```bash
docker compose -f clients/docker-compose.yml --profile python up --abort-on-container-exit
```

## Test

`python -m unittest test_consume.py` returns immediately until `DIAVASI_DATA_ADDR`, `DIAVASI_CA`, and `DIAVASI_API_TOKEN` are set. With those set, it consumes `DIAVASI_TOTAL` records (default 8) from `DIAVASI_GROUP`.

## Stage 0 bench

The TCP bench client in this tree speaks a different protocol from `data.proto`.

```bash
mise install
mise exec -- python -m venv .venv
mise exec -- .venv/bin/pip install -r requirements.txt
mise exec -- .venv/bin/python -m diavasi_bench.gen_proto
```

```bash
# terminal 1
cargo run -p diavasi --bin diavasi-transport-bench --features transport-bench -- \
  --transport tcp --role server --listen 127.0.0.1:9800 --smoke

# terminal 2
PYTHONPATH=. .venv/bin/python -m diavasi_bench \
  --connect 127.0.0.1:9800 --total-records 200 \
  --output docs/bench/results.jsonl
```
