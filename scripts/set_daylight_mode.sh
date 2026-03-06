#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-status}"
SURFACE_NAME="${SURFACE_NAME:-nauvis}"
RCON_HOST="${RCON_HOST:-127.0.0.1}"
RCON_PORT="${RCON_PORT:-27015}"
RCON_PASSWORD="${RCON_PASSWORD:-fwai-local}"

case "$MODE" in
  on)
    LUA_MODE="true"
    ;;
  off)
    LUA_MODE="false"
    ;;
  status)
    LUA_MODE=""
    ;;
  *)
    echo "Usage: ./scripts/set_daylight_mode.sh [on|off|status]" >&2
    exit 1
    ;;
esac

cd "$ROOT_DIR/controller"
env \
  PYTHONPATH=src \
  RCON_HOST="$RCON_HOST" \
  RCON_PORT="$RCON_PORT" \
  RCON_PASSWORD="$RCON_PASSWORD" \
  SURFACE_NAME="$SURFACE_NAME" \
  LUA_MODE="$LUA_MODE" \
  python3 - <<'PY'
from __future__ import annotations

import json
import os

from fwai.rcon_client import RCONClient


def main() -> int:
    host = os.environ["RCON_HOST"]
    port = int(os.environ["RCON_PORT"])
    password = os.environ["RCON_PASSWORD"]
    surface_name = os.environ["SURFACE_NAME"]
    lua_mode = os.environ["LUA_MODE"]

    if lua_mode:
        command = (
            "/c "
            f"local surface = game.surfaces['{surface_name}'] or game.surfaces[1]; "
            "if not surface then rcon.print('{\"ok\":false,\"reason\":\"surface_not_found\"}') return end; "
            f"surface.always_day = {lua_mode}; "
            "rcon.print(helpers.table_to_json({ok=true, surface=surface.name, always_day=surface.always_day, daytime=surface.daytime}))"
        )
    else:
        command = (
            "/c "
            f"local surface = game.surfaces['{surface_name}'] or game.surfaces[1]; "
            "if not surface then rcon.print('{\"ok\":false,\"reason\":\"surface_not_found\"}') return end; "
            "rcon.print(helpers.table_to_json({ok=true, surface=surface.name, always_day=surface.always_day, daytime=surface.daytime}))"
        )

    client = RCONClient(host=host, port=port, password=password)
    try:
        raw = client.command(command).strip()
    finally:
        client.close()

    parsed = json.loads(raw)
    print(json.dumps(parsed, ensure_ascii=False, indent=2))
    return 0 if parsed.get("ok", False) else 1


if __name__ == "__main__":
    raise SystemExit(main())
PY
