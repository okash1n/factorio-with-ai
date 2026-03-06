#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FACTORIO_BIN="${FACTORIO_BIN:-$HOME/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio}"
RUNTIME_DIR="$ROOT_DIR/.runtime/client"
WRITE_DATA_DIR="$RUNTIME_DIR/write-data"
MOD_DIR="$RUNTIME_DIR/mods"
CONFIG_INI="$RUNTIME_DIR/config.ini"
SERVER_ADDR="${1:-127.0.0.1:34197}"

if [[ ! -x "$FACTORIO_BIN" ]]; then
  echo "Factorio binary not found or not executable: $FACTORIO_BIN" >&2
  exit 1
fi

mkdir -p "$WRITE_DATA_DIR" "$MOD_DIR"
"$ROOT_DIR/scripts/prepare_runtime_mods.sh" "$MOD_DIR"

cat > "$CONFIG_INI" <<EOF
[path]
read-data=__PATH__system-read-data__
write-data=$WRITE_DATA_DIR
EOF

exec "$FACTORIO_BIN" \
  --config "$CONFIG_INI" \
  --mod-directory "$MOD_DIR" \
  --mp-connect "$SERVER_ADDR"
