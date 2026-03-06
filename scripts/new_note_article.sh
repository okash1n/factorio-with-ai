#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BASE_DIR="notes"
ARTICLE_TYPE="progress"
ARTICLE_SLUG=""
ARTICLE_TITLE=""
ARTICLE_DATE="$(date +%Y-%m-%d)"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./scripts/new_note_article.sh --slug SLUG [options]

Options:
  --title TEXT       Article title
  --slug SLUG        ASCII slug, for example first-working-bot
  --type TYPE        kickoff or progress (default: progress)
  --date YYYY-MM-DD  Article date (default: today)
  --base-dir DIR     Notes base directory (default: notes)
  --dry-run          Print the target path without writing files
  -h, --help         Show this help
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

default_title() {
  local article_type="$1"
  local day_label="$2"
  case "$article_type" in
    kickoff)
      printf 'Factorio Space AgeをCodexにクリアさせたい Day%s' "$day_label"
      ;;
    progress)
      printf 'Factorio Space AgeをCodexにクリアさせたい Day%s' "$day_label"
      ;;
    *)
      printf 'Factorio Space AgeをCodexにクリアさせたい Day%s' "$day_label"
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)
      ARTICLE_TITLE="$2"
      shift 2
      ;;
    --slug)
      ARTICLE_SLUG="$2"
      shift 2
      ;;
    --type)
      ARTICLE_TYPE="$2"
      shift 2
      ;;
    --date)
      ARTICLE_DATE="$2"
      shift 2
      ;;
    --base-dir)
      BASE_DIR="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
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

if [[ -z "$ARTICLE_SLUG" ]]; then
  echo "--slug is required" >&2
  exit 1
fi

if [[ ! "$ARTICLE_SLUG" =~ ^[a-z0-9-]+$ ]]; then
  echo "--slug must match ^[a-z0-9-]+$" >&2
  exit 1
fi

if [[ "$ARTICLE_TYPE" != "kickoff" && "$ARTICLE_TYPE" != "progress" ]]; then
  echo "--type must be kickoff or progress" >&2
  exit 1
fi

NOTES_DIR="$(resolve_path "$BASE_DIR")"
TEMPLATE_PATH="$ROOT_DIR/notes/templates/$ARTICLE_TYPE.md"

if [[ ! -f "$TEMPLATE_PATH" ]]; then
  echo "template not found: $TEMPLATE_PATH" >&2
  exit 1
fi

mkdir -p "$NOTES_DIR"

next_index=1
while IFS= read -r existing_dir; do
  base_name="$(basename "$existing_dir")"
  if [[ "$base_name" =~ ^([0-9]{3})- ]]; then
    current_index=$((10#${BASH_REMATCH[1]}))
    if (( current_index >= next_index )); then
      next_index=$((current_index + 1))
    fi
  fi
done < <(find "$NOTES_DIR" -mindepth 1 -maxdepth 1 -type d)

printf -v article_index '%03d' "$next_index"
printf -v day_label '%02d' "$next_index"
article_dir="$NOTES_DIR/$article_index-$ARTICLE_SLUG"
article_path="$article_dir/article.md"
images_dir="$article_dir/images"

if [[ -e "$article_dir" ]]; then
  echo "article directory already exists: $article_dir" >&2
  exit 1
fi

if [[ -z "$ARTICLE_TITLE" ]]; then
  ARTICLE_TITLE="$(default_title "$ARTICLE_TYPE" "$day_label")"
fi

if [[ "$DRY_RUN" == "1" ]]; then
  printf 'article_dir=%s\n' "$article_dir"
  printf 'article_path=%s\n' "$article_path"
  printf 'images_dir=%s\n' "$images_dir"
  printf 'template=%s\n' "$TEMPLATE_PATH"
  exit 0
fi

mkdir -p "$images_dir"
TITLE="$ARTICLE_TITLE" DATE="$ARTICLE_DATE" ARTICLE_INDEX="$article_index" DAY_LABEL="$day_label" \
  perl -0pe 's/\{\{TITLE\}\}/$ENV{TITLE}/g; s/\{\{DATE\}\}/$ENV{DATE}/g; s/\{\{ARTICLE_INDEX\}\}/$ENV{ARTICLE_INDEX}/g; s/\{\{DAY_LABEL\}\}/$ENV{DAY_LABEL}/g' \
  "$TEMPLATE_PATH" > "$article_path"

printf 'created=%s\n' "$article_dir"
printf 'article=%s\n' "$article_path"
printf 'images=%s\n' "$images_dir"
