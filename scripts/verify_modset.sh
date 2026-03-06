#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MOD_LIST_PATH="${1:-$HOME/Library/Application Support/Factorio/mods/mod-list.json}"
REQUIRE_FWAI="${REQUIRE_FWAI:-0}"

if [[ ! -f "$MOD_LIST_PATH" ]]; then
  echo "mod-list.json not found: $MOD_LIST_PATH" >&2
  exit 1
fi

python3 - "$MOD_LIST_PATH" "$REQUIRE_FWAI" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
require_fwai = sys.argv[2] == "1"

allowed = {"base", "elevated-rails", "quality", "space-age", "fwai_bridge"}
required = {"base", "elevated-rails", "quality", "space-age"}

doc = json.loads(path.read_text(encoding="utf-8"))
mods = doc.get("mods", [])
enabled = {m["name"] for m in mods if m.get("enabled")}

missing_required = sorted(required - enabled)
unexpected_enabled = sorted(enabled - allowed)

if missing_required:
    print(f"missing required mods: {missing_required}", file=sys.stderr)
    sys.exit(1)

if unexpected_enabled:
    print(f"unexpected enabled mods: {unexpected_enabled}", file=sys.stderr)
    sys.exit(1)

if require_fwai and "fwai_bridge" not in enabled:
    print("fwai_bridge must be enabled for server runtime", file=sys.stderr)
    sys.exit(1)

print("mod set verified:", sorted(enabled))
PY
