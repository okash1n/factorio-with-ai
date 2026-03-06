#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${1:-$ROOT_DIR/dist}"
INFO_JSON="$ROOT_DIR/mod/fwai_bridge/info.json"

if [[ ! -f "$INFO_JSON" ]]; then
  echo "missing info.json: $INFO_JSON" >&2
  exit 1
fi

VERSION="$(python3 - <<PY
import json
from pathlib import Path
info = json.loads(Path("$INFO_JSON").read_text(encoding="utf-8"))
print(info["version"])
PY
)"

mkdir -p "$OUT_DIR"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PKG_DIR="fwai_bridge_${VERSION}"
cp -R "$ROOT_DIR/mod/fwai_bridge" "$TMP_DIR/$PKG_DIR"

OUT_ZIP="$OUT_DIR/${PKG_DIR}.zip"
rm -f "$OUT_ZIP"
(cd "$TMP_DIR" && zip -rq "$OUT_ZIP" "$PKG_DIR")

echo "exported: $OUT_ZIP"
