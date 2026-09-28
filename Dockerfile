FROM python:3.12-slim
RUN pip install --no-cache-dir grpcio protobuf
WORKDIR /app
COPY . /app
RUN chmod +x /app/wait-ca.sh
ENV PYTHONPATH=/app
CMD ["/bin/sh", "-c", "/app/wait-ca.sh && python -m diavasi_client --addr \"$DIAVASI_DATA_ADDR\" --ca \"$DIAVASI_CA\" --token \"$DIAVASI_API_TOKEN\" --group demo --consumer python --total 8"]
