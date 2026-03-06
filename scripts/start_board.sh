#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BOARD_HOST="${BOARD_HOST:-127.0.0.1}"
BOARD_PORT="${BOARD_PORT:-8127}"
OPEN_BROWSER="${OPEN_BROWSER:-1}"

open_host="$BOARD_HOST"
if [[ "$open_host" == "0.0.0.0" ]]; then
  open_host="127.0.0.1"
fi

board_url="http://${open_host}:${BOARD_PORT}"

if [[ "$OPEN_BROWSER" == "1" ]]; then
  (
    sleep 1
    open "$board_url" >/dev/null 2>&1 || true
  ) &
fi

echo "starting board at $board_url"
exec python3 "$ROOT_DIR/board/server.py" --host "$BOARD_HOST" --port "$BOARD_PORT"
