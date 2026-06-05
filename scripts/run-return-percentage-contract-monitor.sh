#!/usr/bin/env bash
set -euo pipefail
export MONITOR_THRESHOLD="${MONITOR_THRESHOLD:-0}"
export MONITOR_SAMPLE_LIMIT="${MONITOR_SAMPLE_LIMIT:-10}"
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run-parse-cloud-monitor.sh" \
  return-percentage-contract-monitor monitor-return-percentage-contract.js
