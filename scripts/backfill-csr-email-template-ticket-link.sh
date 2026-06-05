#!/usr/bin/env bash
# Backfill {{ticketLink}} into CSREmailTemplate (ticket_created, ticket_response, ticket_resolved).
# Runs on Parse host or locally when PARSE_URL + MASTER_KEY are set.
#
# Usage:
#   ./scripts/backfill-csr-email-template-ticket-link.sh           # dry-run
#   ./scripts/backfill-csr-email-template-ticket-link.sh --apply # write DB
#
set -euo pipefail

APPLY=false
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[ -f "$SCRIPT_DIR/.env.server" ] && source "$SCRIPT_DIR/.env.server"

PARSE_HOST="${FIN1_PARSE_CLOUD_SSH_HOST:-${FIN1_SERVER_IP:-192.168.178.20}}"
PARSE_URL="${PARSE_URL:-https://${PARSE_HOST}/parse}"
APP_ID="${PARSE_SERVER_APPLICATION_ID:-${APP_ID:-fin1-app-id}}"

load_env_key() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  grep -E "^${key}=" "$file" | head -1 | cut -d= -f2- | tr -d '"' | tr -d "'"
}

ENV_FILE="${FIN1_SERVER_ENV:-$HOME/fin1-server/backend/.env}"
if [ -z "${PARSE_SERVER_APPLICATION_ID:-}" ]; then
  PARSE_SERVER_APPLICATION_ID="$(load_env_key "$ENV_FILE" PARSE_SERVER_APPLICATION_ID || true)"
fi
if [ -z "${PARSE_SERVER_MASTER_KEY:-}" ]; then
  PARSE_SERVER_MASTER_KEY="$(load_env_key "$ENV_FILE" PARSE_SERVER_MASTER_KEY || true)"
fi

if [ -z "${PARSE_SERVER_MASTER_KEY:-}" ]; then
  echo "Error: PARSE_SERVER_MASTER_KEY not set (export or ~/fin1-server/backend/.env on server)."
  exit 1
fi

DRY_RUN=true
if [ "$APPLY" = true ]; then
  DRY_RUN=false
fi

echo "=== backfillCSREmailTemplateTicketLink (dryRun=$DRY_RUN) ==="
echo "  PARSE_URL=$PARSE_URL"
echo ""

RESP="$(curl -sk --connect-timeout 30 -X POST "${PARSE_URL}/functions/backfillCSREmailTemplateTicketLink" \
  -H "X-Parse-Application-Id: ${APP_ID}" \
  -H "X-Parse-Master-Key: ${PARSE_SERVER_MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"dryRun\":${DRY_RUN}}")"

echo "$RESP" | python3 -m json.tool 2>/dev/null || echo "$RESP"

if echo "$RESP" | grep -q '"error"'; then
  echo ""
  echo "Failed."
  exit 1
fi

if [ "$DRY_RUN" = true ]; then
  echo ""
  echo "Dry-run OK. Apply with: $0 --apply"
fi
