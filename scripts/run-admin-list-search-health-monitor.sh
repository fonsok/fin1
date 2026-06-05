#!/usr/bin/env bash
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run-parse-cloud-monitor.sh" \
  admin-list-search-health-monitor monitor-admin-list-search-health.js
