#!/usr/bin/env bash
# Wrapper for scripts/load-test-signup-onboarding.js (reads scripts/.env.server).
#
# Examples:
#   ./scripts/run-signup-onboarding-load-test.sh
#   LOAD_TEST_USERS=40 LOAD_TEST_CONCURRENCY=20 ./scripts/run-signup-onboarding-load-test.sh
#   LOAD_TEST_ON_SERVER=1 ./scripts/run-signup-onboarding-load-test.sh   # bypass nginx, direct Parse
#   LOAD_TEST_CLEANUP=1 ./scripts/run-signup-onboarding-load-test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
if [ -f "$SCRIPT_DIR/.env.server" ]; then
  set +e
  source "$SCRIPT_DIR/.env.server" 2>/dev/null || true
  set -e
fi

REMOTE_USER="${FIN1_SERVER_USER:-io}"
REMOTE_HOST="${FIN1_PARSE_CLOUD_SSH_HOST:-${FIN1_SERVER_IP:-192.168.178.20}}"

if [[ "${LOAD_TEST_ON_SERVER:-0}" == "1" ]]; then
  rsync -az "$SCRIPT_DIR/load-test-signup-onboarding.js" "${REMOTE_USER}@${REMOTE_HOST}:~/fin1-server/scripts/"
  # shellcheck disable=SC2029
  ssh "${REMOTE_USER}@${REMOTE_HOST}" \
    "cd ~/fin1-server && PARSE_URL='http://127.0.0.1:1338/parse' node scripts/load-test-signup-onboarding.js"
  exit $?
fi

PARSE_HOST="${FIN1_PARSE_CLOUD_SSH_HOST:-${FIN1_SERVER_IP:-192.168.178.20}}"
export PARSE_URL="${PARSE_URL:-https://${PARSE_HOST}/parse}"
export PARSE_APP_ID="${PARSE_APP_ID:-${PARSE_SERVER_APPLICATION_ID:-fin1-app-id}}"

# Dev iobox uses self-signed TLS — parity with curl -sk in smoke scripts.
if [[ "${PARSE_INSECURE_TLS:-1}" == "1" && "${PARSE_URL}" == https://* ]]; then
  export NODE_TLS_REJECT_UNAUTHORIZED=0
fi

exec node "$SCRIPT_DIR/load-test-signup-onboarding.js" "$@"
