#!/usr/bin/env bash
# Post-deploy smoke: admin login + getUserDetails for trader and investor test users.
# Requires BA_PASSWORD in scripts/.env.server (see Documentation/DEV_PORTAL_LOGIN_SSOT.md).
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
TRADER_EMAIL="${SMOKE_TRADER_EMAIL:-trader1@test.com}"
INVESTOR_EMAIL="${SMOKE_INVESTOR_EMAIL:-investor5@test.com}"

if [ -z "${BA_PASSWORD:-}" ]; then
  echo "FAIL: BA_PASSWORD not set." >&2
  echo "  Set in scripts/.env.server (see scripts/.env.server.example)" >&2
  echo "  Docs: Documentation/DEV_PORTAL_LOGIN_SSOT.md" >&2
  exit 2
fi

parse_call() {
  local fn="$1"
  local body="$2"
  local token="${3:-}"
  local headers=(
    -H "X-Parse-Application-Id: ${APP_ID}"
    -H "Content-Type: application/json"
  )
  if [ -n "$token" ]; then
    headers+=(-H "X-Parse-Session-Token: ${token}")
  fi
  curl -sk --connect-timeout 30 -X POST "${PARSE_URL}/functions/${fn}" \
    "${headers[@]}" \
    -d "$body"
}

echo "=== smoke-admin-get-user-details ==="
echo "  PARSE_URL=$PARSE_URL"
echo "  admin=$ADMIN_EMAIL trader=$TRADER_EMAIL investor=$INVESTOR_EMAIL"

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

resolve_user_id() {
  local email="$1"
  local resp
  resp="$(parse_call searchUsers "{\"query\":\"${email}\",\"limit\":20}" "$TOKEN")"
  echo "$resp" | python3 -c "
import json,sys
r=json.load(sys.stdin).get('result',{})
users=r.get('users') or []
email=sys.argv[1].lower()
for u in users:
    if str(u.get('email','')).lower()==email:
        print(u.get('objectId') or '')
        break
" "$email"
}

check_user_details() {
  local label="$1"
  local user_id="$2"
  local expect_role="$3"
  local resp
  resp="$(parse_call getUserDetails "{\"userId\":\"${user_id}\"}" "$TOKEN")"
  echo "$resp" | python3 -c "
import json,sys
label, expect_role = sys.argv[1], sys.argv[2]
raw=json.load(sys.stdin)
if raw.get('error'):
    print(f'FAIL {label}:', raw.get('error'))
    sys.exit(1)
r=raw.get('result', raw)
u=r.get('user') or {}
role=u.get('role')
if role != expect_role:
    print(f'FAIL {label}: expected role {expect_role}, got {role}')
    sys.exit(1)
stmt=r.get('accountStatement') or {}
entries=stmt.get('entries') or []
print(f'  OK {label}: role={role} entries={len(entries)} wallet={(r.get(\"walletControls\") or {}).get(\"effectiveMode\")}')
" "$label" "$expect_role"
}

TRADER_ID="$(resolve_user_id "$TRADER_EMAIL")"
INVESTOR_ID="$(resolve_user_id "$INVESTOR_EMAIL")"
if [ -z "$TRADER_ID" ]; then
  echo "FAIL: user not found: $TRADER_EMAIL" >&2
  echo "  Hint: seed test users (seedTestUsers) or set SMOKE_TRADER_EMAIL in scripts/.env.server" >&2
  exit 1
fi
if [ -z "$INVESTOR_ID" ]; then
  echo "FAIL: user not found: $INVESTOR_EMAIL" >&2
  echo "  Hint: seed test users (seedTestUsers) or set SMOKE_INVESTOR_EMAIL in scripts/.env.server" >&2
  exit 1
fi

check_user_details "trader" "$TRADER_ID" "trader"
check_user_details "investor" "$INVESTOR_ID" "investor"

echo ""
echo "OK: getUserDetails smoke passed."
