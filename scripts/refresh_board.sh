#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"
python3 - <<'PY'
from board.server import load_board, save_board

save_board(load_board())
PY
