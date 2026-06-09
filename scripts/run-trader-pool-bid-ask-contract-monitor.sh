#!/usr/bin/env bash
set -euo pipefail
export TRADER_POOL_BID_ASK_MAX_VIOLATIONS="${TRADER_POOL_BID_ASK_MAX_VIOLATIONS:-0}"
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run-parse-cloud-monitor.sh" \
  trader-pool-bid-ask-contract-monitor monitor-trader-pool-bid-ask-contract.js
