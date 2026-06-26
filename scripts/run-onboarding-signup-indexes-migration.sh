#!/usr/bin/env bash
# Triggers pending Parse schema migrations (incl. onboarding_signup_indexes_v1) and verifies audit row.
#
# Usage:
#   ./scripts/run-onboarding-signup-indexes-migration.sh
#   PARSE_URL=https://127.0.0.1:8443/parse ./scripts/run-onboarding-signup-indexes-migration.sh  # SSH tunnel
#
# Requires BA_PASSWORD in scripts/.env.server (admin@fin1.de).
# Docs: Documentation/SCHEMA_MIGRATIONS.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
if [ -z "${BA_PASSWORD:-}" ] && [ -f "$SCRIPT_DIR/.env.server" ]; then
  set +e
  source "$SCRIPT_DIR/.env.server" 2>/dev/null || true
  set -e
fi

PARSE_HOST="${FIN1_PARSE_CLOUD_SSH_HOST:-${FIN1_SERVER_IP:-192.168.178.20}}"
PARSE_URL="${PARSE_URL:-https://${PARSE_HOST}/parse}"
APP_ID="${PARSE_SERVER_APPLICATION_ID:-fin1-app-id}"
ADMIN_EMAIL="${SMOKE_ADMIN_EMAIL:-admin@fin1.de}"
MIGRATION_ID="${ONBOARDING_SIGNUP_MIGRATION_ID:-onboarding_signup_indexes_v1}"

if [ -z "${BA_PASSWORD:-}" ]; then
  echo "FAIL: BA_PASSWORD not set (scripts/.env.server)" >&2
  exit 2
fi

parse_call() {
  local fn="$1"
  local body="$2"
  local token="$3"
  curl -sk --connect-timeout 30 -X POST "${PARSE_URL}/functions/${fn}" \
    -H "X-Parse-Application-Id: ${APP_ID}" \
    -H "Content-Type: application/json" \
    -H "X-Parse-Session-Token: ${token}" \
    -d "$body"
}

echo "=== run-onboarding-signup-indexes-migration ==="
echo "  PARSE_URL=$PARSE_URL"
echo "  migrationId=$MIGRATION_ID"

LOGIN="$(curl -sk --connect-timeout 15 -X POST "${PARSE_URL}/login" \
  -H "X-Parse-Application-Id: ${APP_ID}" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${ADMIN_EMAIL}\",\"password\":\"${BA_PASSWORD}\"}")"

TOKEN="$(echo "$LOGIN" | python3 -c "import json,sys; print(json.load(sys.stdin).get('sessionToken',''))" 2>/dev/null || true)"
if [ -z "$TOKEN" ]; then
  echo "FAIL: admin login" >&2
  echo "$LOGIN" | python3 -m json.tool 2>/dev/null || echo "$LOGIN"
  exit 1
fi
echo "  OK admin login"

echo "▸ updateInvestmentClassSchemaFields …"
APPLY_RESP="$(parse_call updateInvestmentClassSchemaFields "{}" "$TOKEN")"
echo "$APPLY_RESP" | python3 -c "
import json,sys
raw=json.load(sys.stdin)
if raw.get('error'):
    print('FAIL apply:', raw['error'])
    sys.exit(1)
r=raw.get('result', raw)
ok=bool(r.get('success', r.get('ok', True)))
print('  apply success:', ok)
migrations=(r.get('result') or {}).get('migrations') or r.get('migrations') or []
for row in migrations:
    if row.get('migrationId') == sys.argv[1]:
        print('  migration row:', row)
" "$MIGRATION_ID" || {
  echo "$APPLY_RESP" | python3 -m json.tool 2>/dev/null || echo "$APPLY_RESP"
  exit 1
}

echo "▸ listSchemaMigrations …"
LIST_RESP="$(parse_call listSchemaMigrations "{\"limit\":80}" "$TOKEN")"
echo "$LIST_RESP" | python3 -c "
import json,sys
target=sys.argv[1]
raw=json.load(sys.stdin)
if raw.get('error'):
    print('FAIL list:', raw['error'])
    sys.exit(1)
rows=(raw.get('result') or raw).get('rows') or []
match=[r for r in rows if r.get('migrationId')==target]
if not match:
    print(f'FAIL: no audit row for {target}')
    sys.exit(1)
latest=match[0]
if not latest.get('success'):
    print(f'FAIL: {target} success=false')
    print(json.dumps(latest, indent=2))
    sys.exit(1)
print(f'  OK {target}: success=true appliedAt={latest.get(\"appliedAt\")}')
note=latest.get('applyNote') or latest.get('applyMessage')
if note:
    print('  note:', note)
" "$MIGRATION_ID"

echo ""
echo "OK: onboarding signup indexes migration verified."
