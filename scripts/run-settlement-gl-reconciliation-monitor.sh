#!/usr/bin/env bash
set -euo pipefail
export SETTLEMENT_GL_RECON_MAX_VIOLATIONS="${SETTLEMENT_GL_RECON_MAX_VIOLATIONS:-0}"
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run-parse-cloud-monitor.sh" \
  settlement-gl-reconciliation-monitor monitor-settlement-gl-reconciliation.js
