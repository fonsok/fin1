#!/usr/bin/env bash
# Remove local build / dependency artifacts before copying FIN1 to another disk.
# Targets match .gitignore (build/, node_modules/, .venv_*/, etc.).
#
# Recreates later with: xcodebuild / npm install / python -m venv
#
# Usage:
#   ./scripts/clean-for-export.sh              # delete artifacts
#   ./scripts/clean-for-export.sh --dry-run    # show what would be removed
#   ./scripts/clean-for-export.sh --keep-node  # only Xcode/Swift build dirs

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DRY_RUN=false
KEEP_NODE=false
INCLUDE_BUNDLE=false

usage() {
  cat <<'EOF'
Usage: ./scripts/clean-for-export.sh [options]

Removes ignored local artifacts so copying FIN1 stays small (~10–50 MB source).

Options:
  --dry-run          List paths and sizes; do not delete
  --keep-node        Keep node_modules, dist, admin/ bundle; only Xcode/Swift build dirs
  --include-bundle   Also remove fin1-return-contract.bundle (gitignored transport artifact)
  -h, --help         Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --keep-node) KEEP_NODE=true ;;
    --include-bundle) INCLUDE_BUNDLE=true ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

human_size() {
  du -sh "$1" 2>/dev/null | awk '{print $1}' || echo "?"
}

remove_path() {
  local rel="$1"
  local path="$ROOT/$rel"
  if [[ ! -e "$path" ]]; then
    return 0
  fi
  local size
  size="$(human_size "$path")"
  if $DRY_RUN; then
    echo "  would remove  $rel  ($size)"
  else
    rm -rf "$path"
    echo "  removed     $rel  ($size)"
  fi
}

# Relative paths (stable order: largest impact first)
BUILD_PATHS=(
  build/
  DerivedData/
  .build/
)

NODE_PATHS=(
  admin-portal/node_modules
  admin-portal/dist
  admin-portal/coverage
  backend/parse-server/node_modules
  admin/
)

OTHER_PATHS=(__pycache__)

shopt -s nullglob
for v in "$ROOT"/.venv_*; do
  [[ -e "$v" ]] || continue
  OTHER_PATHS+=("${v#$ROOT/}")
done
shopt -u nullglob

PATHS=("${BUILD_PATHS[@]}")
if ! $KEEP_NODE; then
  PATHS+=("${NODE_PATHS[@]}")
fi
PATHS+=("${OTHER_PATHS[@]}")

if $INCLUDE_BUNDLE; then
  PATHS+=(fin1-return-contract.bundle)
fi

echo "FIN1 clean-for-export"
echo "  root: $ROOT"
if $DRY_RUN; then
  echo "  mode: dry-run"
elif $KEEP_NODE; then
  echo "  mode: build only (--keep-node)"
else
  echo "  mode: full clean"
fi
echo ""

before="$(human_size "$ROOT")"
echo "Size before: $before"
echo ""

found=0
for rel in "${PATHS[@]}"; do
  if [[ -e "$ROOT/$rel" ]]; then
    found=1
    remove_path "$rel"
  fi
done

if [[ $found -eq 0 ]]; then
  echo "  (nothing to remove — already lean)"
fi

echo ""
if $DRY_RUN; then
  echo "Dry-run complete. Re-run without --dry-run to delete."
else
  after="$(human_size "$ROOT")"
  echo "Size after:  $after  (was $before)"
  echo ""
  echo "Restore when needed:"
  echo "  iOS build:     open FIN1.xcodeproj and build, or ./scripts/check-bundle-size.sh"
  echo "  admin-portal:  cd admin-portal && npm ci"
  echo "  parse-server:  cd backend/parse-server && npm ci"
fi
