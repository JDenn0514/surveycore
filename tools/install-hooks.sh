#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
HOOK="$ROOT/.git/hooks/pre-commit"
TARGET="../../tools/pre-commit"

if [[ -L "$HOOK" && "$(readlink "$HOOK")" == "$TARGET" ]]; then
  echo "pre-commit hook already installed."
  exit 0
fi

if [[ -f "$HOOK" && ! -L "$HOOK" ]]; then
  echo "Backing up existing pre-commit hook to $HOOK.bak"
  mv "$HOOK" "$HOOK.bak"
fi

ln -sf "$TARGET" "$HOOK"
echo "Installed: .git/hooks/pre-commit -> $TARGET"
