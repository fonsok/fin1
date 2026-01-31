#!/bin/bash
set -euo pipefail

# v2026-01-31

if ! command -v git >/dev/null 2>&1; then
  echo "git not found."
  exit 1
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not a git repository (no .git directory). Skipping hook install."
  exit 0
fi

repo_root="$(git rev-parse --show-toplevel)"
hooks_dir="$repo_root/.git/hooks"

mkdir -p "$hooks_dir"
cp "$repo_root/.githooks/pre-commit" "$hooks_dir/pre-commit"

chmod +x "$hooks_dir/pre-commit" \
  "$repo_root/.githooks/pre-commit" \
  "$repo_root/scripts/check-xcode-display-name-v2026-01-31.sh"

echo "✅ Installed pre-commit hook to $hooks_dir/pre-commit"

