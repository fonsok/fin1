#!/usr/bin/env bash
# Validate FIN1 production xcconfig chain before App Store / release builds.
# CI sets FIN1_ALLOW_PROD_PLACEHOLDERS=1 so TODOs in Config/FIN1-Prod.xcconfig do not fail the job.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROD="${ROOT}/Config/FIN1-Prod.xcconfig"
RELEASE="${ROOT}/Config/FIN1-Release.xcconfig"

if [[ ! -f "$PROD" ]]; then
  echo "check-prod-xcconfig: missing ${PROD}" >&2
  exit 1
fi
if [[ ! -f "$RELEASE" ]]; then
  echo "check-prod-xcconfig: missing ${RELEASE}" >&2
  exit 1
fi

if ! grep -q '#include "FIN1-Prod.xcconfig"' "$RELEASE"; then
  echo "check-prod-xcconfig: FIN1-Release.xcconfig must include FIN1-Prod.xcconfig" >&2
  exit 1
fi

if ! grep -qE '^[[:space:]]*FIN1_PARSE_SERVER_URL[[:space:]]*=' "$PROD"; then
  echo "check-prod-xcconfig: FIN1-Prod.xcconfig must set FIN1_PARSE_SERVER_URL" >&2
  exit 1
fi

if [[ "${FIN1_ALLOW_PROD_PLACEHOLDERS:-0}" != "1" ]]; then
  if grep -qiE 'TODO|FIXME|CHANGEME|REPLACE_ME' "$PROD"; then
    echo "check-prod-xcconfig: FIN1-Prod.xcconfig still has placeholder markers (or set FIN1_ALLOW_PROD_PLACEHOLDERS=1 in CI)." >&2
    exit 1
  fi
fi

echo "OK: prod xcconfig release check passed (${PROD})"
exit 0
