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

# Prefer a symlink so updates to `.githooks/pre-commit` are picked up automatically.
# This also avoids cp failing when the hook already points to the same file.
ln -sf "../../.githooks/pre-commit" "$hooks_dir/pre-commit"

chmod +x "$hooks_dir/pre-commit" \
  "$repo_root/.githooks/pre-commit" \
  "$repo_root/scripts/check-xcode-display-name.sh" \
  "$repo_root/scripts/check-parse-cloud-config-helper-shadow.sh" \
  "$repo_root/scripts/check-parse-cloud-naming-conventions.sh"

echo "✅ Installed pre-commit hook to $hooks_dir/pre-commit (symlink to .githooks/pre-commit)"

