#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT_MOD_DIR="${1:-$HOME/Library/Application Support/Factorio/mods}"
LINK_MODE="${LINK_MODE:-1}"

mkdir -p "$CLIENT_MOD_DIR"

if [[ "$LINK_MODE" == "1" ]]; then
  rm -rf "$CLIENT_MOD_DIR/fwai_bridge"
  ln -s "$ROOT_DIR/mod/fwai_bridge" "$CLIENT_MOD_DIR/fwai_bridge"
  cat > "$CLIENT_MOD_DIR/mod-list.json" <<'JSON'
{
  "mods": [
    {"name": "base", "enabled": true},
    {"name": "elevated-rails", "enabled": true},
    {"name": "quality", "enabled": true},
    {"name": "space-age", "enabled": true},
    {"name": "fwai_bridge", "enabled": true}
  ]
}
JSON
  REQUIRE_FWAI=1 "$ROOT_DIR/scripts/verify_modset.sh" "$CLIENT_MOD_DIR/mod-list.json"
  echo "installed client mod set (symlink mode) to: $CLIENT_MOD_DIR"
  echo "fwai_bridge -> $ROOT_DIR/mod/fwai_bridge"
else
  "$ROOT_DIR/scripts/prepare_runtime_mods.sh" "$CLIENT_MOD_DIR"
  echo "installed client mod set (copy mode) to: $CLIENT_MOD_DIR"
fi
