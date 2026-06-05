#!/usr/bin/env bash
set -euo pipefail
# Backward-compatible alias — installs all iobox monitor cron entries.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install-iobox-monitors-cron.sh" "$@"
