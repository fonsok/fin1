#!/usr/bin/env bash
set -euo pipefail
export PAIRED_STATUS_MAX_VIOLATIONS="${PAIRED_STATUS_MAX_VIOLATIONS:-0}"
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run-parse-cloud-monitor.sh" \
  paired-order-status-monitor monitor-paired-order-status-integrity.js
