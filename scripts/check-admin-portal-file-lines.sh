#!/usr/bin/env bash
# Advisory file-size check for admin-portal/src (see Documentation/ADMIN_PORTAL_NAMING_CONVENTIONS.md).
# Default: exit 0 and print warnings. Use --strict to fail CI/review gates.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/admin-portal/src"
STRICT=0
if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
fi

if [[ ! -d "$SRC" ]]; then
  echo "SKIP: $SRC not found."
  exit 0
fi

DEFAULT_MAX=300
PAGE_MAX=400
violations=0

while IFS= read -r -d '' file; do
  rel="${file#"$ROOT"/}"
  base="$(basename "$file")"
  lines="$(wc -l <"$file" | tr -d ' ')"
  max="$DEFAULT_MAX"
  if [[ "$base" == *Page.tsx ]]; then
    max="$PAGE_MAX"
  fi
  if (( lines > max )); then
    echo "WARN  $rel: $lines lines (limit $max)"
    violations=$((violations + 1))
  fi
done < <(
  find "$SRC" -type f \( -name '*.ts' -o -name '*.tsx' \) \
    ! -path '*/test/*' \
    ! -name '*.test.ts' \
    ! -name '*.test.tsx' \
    ! -name '*.spec.ts' \
    ! -name '*.spec.tsx' \
    -print0
)

if (( violations == 0 )); then
  echo "OK: admin-portal file line counts within limits."
  exit 0
fi

echo ""
echo "Advisory: $violations file(s) exceed admin-portal line limits ($DEFAULT_MAX / $PAGE_MAX for *Page.tsx)."
echo "Split into feature modules (see Documentation/ADMIN_PORTAL_NAMING_CONVENTIONS.md)."
echo "Local: ./scripts/check-admin-portal-file-lines.sh  |  ESLint: cd admin-portal && npm run lint:file-size"

if (( STRICT == 1 )); then
  exit 1
fi
exit 0
