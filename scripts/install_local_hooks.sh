#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$ROOT_DIR/.git/hooks"
SOURCE_HOOK="$ROOT_DIR/.project/hooks/pre-commit"
TARGET_HOOK="$HOOKS_DIR/pre-commit"

mkdir -p "$HOOKS_DIR"
chmod +x "$SOURCE_HOOK"
ln -sfn "$SOURCE_HOOK" "$TARGET_HOOK"

echo "installed: $TARGET_HOOK -> $SOURCE_HOOK"
