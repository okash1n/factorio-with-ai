#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
RCON_HOST="${RCON_HOST:-127.0.0.1}"
RCON_PORT="${RCON_PORT:-27015}"
RCON_PASSWORD="${RCON_PASSWORD:-fwai-local}"
LOOP_SECONDS="${LOOP_SECONDS:-1.0}"
ITERATIONS="${ITERATIONS:-0}"
PLAYER_INDEX="${PLAYER_INDEX:-1}"

export PYTHONPATH="$ROOT_DIR/controller/src"

exec "$PYTHON_BIN" -m fwai.main \
  --rcon-host "$RCON_HOST" \
  --rcon-port "$RCON_PORT" \
  --rcon-password "$RCON_PASSWORD" \
  --loop-seconds "$LOOP_SECONDS" \
  --iterations "$ITERATIONS" \
  --player-index "$PLAYER_INDEX"
