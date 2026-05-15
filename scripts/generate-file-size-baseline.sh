#!/usr/bin/env bash
# Regenerate scripts/file-size-baseline.json from current FIN1/ Swift sources (>300 lines).
# Excludes legal static copy (PrivacyPolicy/TermsOfService globs — same as check).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
chmod +x scripts/file_size_baseline.py
exec python3 scripts/file_size_baseline.py generate
