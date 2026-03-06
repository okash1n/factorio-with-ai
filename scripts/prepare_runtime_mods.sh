#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_MOD_DIR="${1:-}"

if [[ -z "$TARGET_MOD_DIR" ]]; then
  echo "usage: $0 <target-mod-dir>" >&2
  exit 1
fi

mkdir -p "$TARGET_MOD_DIR"

rm -rf "$TARGET_MOD_DIR/fwai_bridge"
cp -R "$ROOT_DIR/mod/fwai_bridge" "$TARGET_MOD_DIR/fwai_bridge"

cat > "$TARGET_MOD_DIR/mod-list.json" <<'JSON'
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

REQUIRE_FWAI=1 "$ROOT_DIR/scripts/verify_modset.sh" "$TARGET_MOD_DIR/mod-list.json"
