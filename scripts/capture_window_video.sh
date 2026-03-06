#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROCESS_NAME="${PROCESS_NAME:-factorio}"
WINDOW_INDEX=1
ARTICLE_DIR=""
OUTPUT_DIR=""
FILE_STEM=""
DURATION_SECONDS="${DURATION_SECONDS:-8}"

usage() {
  cat <<'EOF'
Usage: ./scripts/capture_window_video.sh [options]

Options:
  --article-dir DIR   Save to DIR/images
  --output-dir DIR    Save to DIR
  --name STEM         File name stem without extension
  --process NAME      Process name for AppleScript lookup
  --window-index N    Window index to capture
  --duration SEC      Max recording duration in seconds
  -h, --help          Show this help
EOF
}

resolve_path() {
  local input="$1"
  if [[ "$input" = /* ]]; then
    printf '%s\n' "$input"
  else
    printf '%s/%s\n' "$ROOT_DIR" "$input"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --article-dir)
      ARTICLE_DIR="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --name)
      FILE_STEM="$2"
      shift 2
      ;;
    --process)
      PROCESS_NAME="$2"
      shift 2
      ;;
    --window-index)
      WINDOW_INDEX="$2"
      shift 2
      ;;
    --duration)
      DURATION_SECONDS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -n "$ARTICLE_DIR" && -n "$OUTPUT_DIR" ]]; then
  echo "--article-dir and --output-dir cannot be used together" >&2
  exit 1
fi

if [[ -n "$ARTICLE_DIR" ]]; then
  ARTICLE_DIR="$(resolve_path "$ARTICLE_DIR")"
  OUTPUT_DIR="$ARTICLE_DIR/images"
else
  OUTPUT_DIR="$(resolve_path "${OUTPUT_DIR:-notes/_captures}")"
fi

mkdir -p "$OUTPUT_DIR"

timestamp="$(date +%Y%m%d-%H%M%S)"
file_stem="${FILE_STEM:-window-video-$timestamp}"
target_path="$OUTPUT_DIR/$file_stem.mov"

set +e
bounds_output="$(osascript - "$PROCESS_NAME" "$WINDOW_INDEX" 2>&1 <<'APPLESCRIPT'
on run argv
  set processName to item 1 of argv
  set windowIndex to (item 2 of argv) as integer

  tell application "System Events"
    if not (exists process processName) then
      error "process not found: " & processName
    end if

    tell process processName
      if (count of windows) < windowIndex then
        error "window index out of range"
      end if

      set targetWindow to window windowIndex
      set {x, y} to position of targetWindow
      set {w, h} to size of targetWindow
      return (x as text) & "," & (y as text) & "," & (w as text) & "," & (h as text)
    end tell
  end tell
end run
APPLESCRIPT
)"
status=$?
set -e

if [[ $status -ne 0 ]]; then
  if [[ "$bounds_output" == *"-25211"* ]]; then
    echo "Accessibility permission is required for osascript/System Events." >&2
    echo "Enable it for Codex in System Settings > Privacy & Security > Accessibility." >&2
  else
    printf '%s\n' "$bounds_output" >&2
  fi
  exit 1
fi

IFS=',' read -r x y w h <<< "$bounds_output"

set +e
capture_output="$(screencapture -v -V"$DURATION_SECONDS" -R"${x},${y},${w},${h}" "$target_path" 2>&1)"
status=$?
set -e

if [[ $status -ne 0 ]]; then
  if [[ "$capture_output" == *"could not create movie from display"* ]] || [[ "$capture_output" == *"permission"* ]]; then
    echo "Screen Recording permission is required for screencapture video." >&2
    echo "Enable it for Codex in System Settings > Privacy & Security > Screen Recording." >&2
  else
    printf '%s\n' "$capture_output" >&2
  fi
  exit 1
fi

printf 'saved=%s\n' "$target_path"
printf 'bounds=%s\n' "$bounds_output"
printf 'duration=%s\n' "$DURATION_SECONDS"
