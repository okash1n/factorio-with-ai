#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: ./scripts/convert_mov_to_gif.sh INPUT.mov OUTPUT.gif" >&2
  exit 1
fi

INPUT_PATH="$1"
OUTPUT_PATH="$2"
FPS="${FPS:-12}"
WIDTH="${WIDTH:-960}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

run_convert() {
  ffmpeg -y -i "$INPUT_PATH" -vf "fps=${FPS},scale=${WIDTH}:-1:flags=lanczos" "$TMP_DIR/frame-%04d.png"
  gifski --fps "$FPS" --output "$OUTPUT_PATH" "$TMP_DIR"/frame-*.png
}

if command -v ffmpeg >/dev/null 2>&1 && command -v gifski >/dev/null 2>&1; then
  run_convert
else
  nix shell nixpkgs#ffmpeg nixpkgs#gifski --command bash -lc "
    set -euo pipefail
    ffmpeg -y -i '$INPUT_PATH' -vf 'fps=${FPS},scale=${WIDTH}:-1:flags=lanczos' '$TMP_DIR/frame-%04d.png'
    gifski --fps ${FPS} --output '$OUTPUT_PATH' '$TMP_DIR'/frame-*.png
  "
fi
