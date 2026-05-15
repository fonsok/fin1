#!/usr/bin/env bash
# File size validation — CI uses --mode baseline (grandfather + no growth).
# Strict mode: all FIN1 Swift files ≤300 lines (local / burn-down).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
chmod +x scripts/file_size_baseline.py

MODE="baseline"
if [[ "${1:-}" == "--mode" && -n "${2:-}" ]]; then
  MODE="$2"
elif [[ "${1:-}" == "--strict" ]]; then
  MODE="strict"
fi

exec python3 scripts/file_size_baseline.py check --mode "$MODE"
