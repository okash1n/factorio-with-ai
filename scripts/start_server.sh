#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FACTORIO_BIN="${FACTORIO_BIN:-$HOME/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio}"
RUNTIME_DIR="$ROOT_DIR/.runtime/server"
WRITE_DATA_DIR="$RUNTIME_DIR/write-data"
MOD_DIR="$RUNTIME_DIR/mods"
CONFIG_INI="$RUNTIME_DIR/config.ini"
SAVE_NAME="${SAVE_NAME:-space-age-main.zip}"
SAVE_FILE="$WRITE_DATA_DIR/saves/$SAVE_NAME"
SERVER_SETTINGS="$ROOT_DIR/configs/server-settings.json"
RCON_PORT="${RCON_PORT:-27015}"
RCON_PASSWORD="${RCON_PASSWORD:-fwai-local}"
GAME_PORT="${GAME_PORT:-34197}"

if [[ ! -x "$FACTORIO_BIN" ]]; then
  echo "Factorio binary not found or not executable: $FACTORIO_BIN" >&2
  exit 1
fi

mkdir -p "$WRITE_DATA_DIR/saves" "$MOD_DIR"

"$ROOT_DIR/scripts/prepare_runtime_mods.sh" "$MOD_DIR"

cat > "$CONFIG_INI" <<EOF
[path]
read-data=__PATH__system-read-data__
write-data=$WRITE_DATA_DIR
EOF

if [[ ! -f "$SAVE_FILE" ]]; then
  "$FACTORIO_BIN" \
    --config "$CONFIG_INI" \
    --mod-directory "$MOD_DIR" \
    --create "$SAVE_FILE"
fi

exec "$FACTORIO_BIN" \
  --config "$CONFIG_INI" \
  --mod-directory "$MOD_DIR" \
  --port "$GAME_PORT" \
  --start-server "$SAVE_FILE" \
  --server-settings "$SERVER_SETTINGS" \
  --rcon-port "$RCON_PORT" \
  --rcon-password "$RCON_PASSWORD"
