#!/usr/bin/env bash
set -euo pipefail
version=$(python3 - <<'PY'
import tomllib
print(tomllib.load(open("pyproject.toml", "rb"))["project"]["version"])
PY
)
tag="${GITHUB_REF_NAME:-}"
if [[ -n "$tag" && "$tag" != "v${version}" ]]; then
  echo "tag ${tag} does not match package version ${version}" >&2
  exit 1
fi
python -m pip install build twine
python -m build
python -m twine check dist/*
if [[ "${DRY_RUN:-0}" == 1 ]]; then
  exit 0
fi
python -m twine upload dist/*
