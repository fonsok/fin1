#!/usr/bin/env bash
set -euo pipefail
export MIRROR_DRIFT_MAX_DRIFTED="${MIRROR_DRIFT_MAX_DRIFTED:-0}"
export MIRROR_DRIFT_MAX_AGE_SECONDS="${MIRROR_DRIFT_MAX_AGE_SECONDS:-691200}"
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run-parse-cloud-monitor.sh" \
  mirror-basis-drift-monitor monitor-mirror-basis-drift-contract.js
