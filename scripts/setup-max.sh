#!/bin/sh
# Makes the Python venv that holds Modular MAX 26.7, for examples/, opcheck/ and apicheck/: MAX
# ships as a Python package, whose wheel carries libmax.so, its C headers and its kernels, and NumPy
# comes with it. The venv is .venv at the repository root, or MAX_VENV. Needs uv.
#
#   scripts/setup-max.sh          (each Makefile runs it when the venv is missing)
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
venv=${MAX_VENV:-$here/.venv}
if [ -x "$venv/bin/python" ]; then
    exit 0
fi
command -v uv >/dev/null || { echo "setup-max: uv is needed (https://docs.astral.sh/uv/)" >&2; exit 1; }
uv venv -q "$venv" --python 3.11
uv pip install -q --python "$venv/bin/python" "max==26.7.*"
echo "setup-max: MAX in $venv"
