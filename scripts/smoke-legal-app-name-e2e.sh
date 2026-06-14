#!/usr/bin/env bash
# E2E smoke: legalAppName 4-eyes (requestConfigurationChange → approveRequest → verify → revert).
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
REQUESTER_EMAIL="${SMOKE_REQUESTER_EMAIL:-admin@fin1.de}"
APPROVER_EMAIL="${SMOKE_APPROVER_EMAIL:-finance@fin1.de}"
REQUESTER_PASSWORD="${SMOKE_REQUESTER_PASSWORD:-${BA_PASSWORD:-}}"
APPROVER_PASSWORD="${SMOKE_APPROVER_PASSWORD:-${BA_PASSWORD:-}}"
REASON="${SMOKE_LEGAL_APP_NAME_REASON:-E2E smoke: legalAppName 4-eyes test}"

if [ -z "${REQUESTER_PASSWORD}" ] || [ -z "${APPROVER_PASSWORD}" ]; then
  echo "FAIL: REQUESTER/APPROVER password not set." >&2
  echo "  Set BA_PASSWORD in scripts/.env.server" >&2
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

login() {
  local email="$1"
  local pass="$2"
  local body
  body="$(EMAIL="$email" PASS="$pass" python3 -c 'import json,os; print(json.dumps({"username":os.environ["EMAIL"],"password":os.environ["PASS"]}))')"
  local resp
  resp="$(curl -sk --connect-timeout 15 -X POST "${PARSE_URL}/login" \
    -H "X-Parse-Application-Id: ${APP_ID}" \
    -H "Content-Type: application/json" \
    -d "$body")"
  if [ -z "$resp" ]; then
    echo "FAIL: empty login response for ${email}" >&2
    return 1
  fi
  echo "$resp" | python3 -c "
import json,sys
raw=json.load(sys.stdin)
if raw.get('error'):
    sys.stderr.write(str(raw.get('error','login failed')) + '\n')
    sys.exit(1)
print(raw.get('sessionToken',''))
" 2>/dev/null || return 1
}

echo "=== smoke-legal-app-name-e2e ==="
echo "  PARSE_URL=$PARSE_URL"
echo "  requester=$REQUESTER_EMAIL approver=$APPROVER_EMAIL"

REQUESTER_TOKEN="$(login "$REQUESTER_EMAIL" "$REQUESTER_PASSWORD")"
if [ -z "$REQUESTER_TOKEN" ]; then
  echo "FAIL: requester login ($REQUESTER_EMAIL)" >&2
  exit 1
fi
echo "  OK requester login"

APPROVER_TOKEN="$(login "$APPROVER_EMAIL" "$APPROVER_PASSWORD")"
if [ -z "$APPROVER_TOKEN" ]; then
  echo "FAIL: approver login ($APPROVER_EMAIL)" >&2
  exit 1
fi
echo "  OK approver login"

export PARSE_URL APP_ID REASON REQUESTER_TOKEN APPROVER_TOKEN

python3 <<'PY'
import json
import os
import subprocess
import sys

PARSE_URL = os.environ["PARSE_URL"]
APP_ID = os.environ["APP_ID"]
REASON = os.environ["REASON"]


def parse_call(fn, body, token=None):
    cmd = [
        "curl", "-sk", "--connect-timeout", "30",
        "-X", "POST", f"{PARSE_URL}/functions/{fn}",
        "-H", f"X-Parse-Application-Id: {APP_ID}",
        "-H", "Content-Type: application/json",
    ]
    if token:
        cmd.extend(["-H", f"X-Parse-Session-Token: {token}"])
    cmd.extend(["-d", json.dumps(body)])
    out = subprocess.check_output(cmd, text=True)
    raw = json.loads(out)
    if raw.get("error"):
        raise RuntimeError(f"{fn}: {raw['error']}")
    return raw.get("result", raw)


def read_legal_app_name(token):
    cfg = parse_call("getConfiguration", {}, token)
    flat = cfg.get("config") or {}
    legal = cfg.get("legal") or {}
    name = flat.get("legalAppName") or legal.get("appName")
    if not name or not str(name).strip():
        raise RuntimeError("legalAppName missing in getConfiguration")
    return str(name).strip()


def alternate_name(current):
    suffix = " E2E"
    candidate = f"{current}{suffix}" if suffix not in current else current.replace(suffix, " Test")
    candidate = candidate.strip()
    if len(candidate) > 120:
        candidate = candidate[:120].rstrip()
    if candidate == current:
        candidate = "FIN1 E2E" if current != "FIN1 E2E" else "FIN1"
    if not candidate:
        raise RuntimeError("Could not derive alternate legalAppName")
    return candidate


def assert_name(token, expected, label):
    actual = read_legal_app_name(token)
    if actual != expected:
        raise RuntimeError(f"{label}: expected {expected!r}, got {actual!r}")
    print(f"  OK {label}: legalAppName={actual!r}")


def request_change(token, new_value, reason):
    result = parse_call(
        "requestConfigurationChange",
        {
            "parameterName": "legalAppName",
            "newValue": new_value,
            "reason": reason,
        },
        token,
    )
    if not result.get("success") or not result.get("fourEyesRequestId"):
        raise RuntimeError(f"requestConfigurationChange failed: {result}")
    return result["fourEyesRequestId"]


def approve_request(token, request_id):
    result = parse_call(
        "approveRequest",
        {"requestId": request_id, "notes": "E2E smoke approve"},
        token,
    )
    if not result.get("success") or not result.get("applied"):
        raise RuntimeError(f"approveRequest failed: {result}")
    return result


requester = os.environ["REQUESTER_TOKEN"]
approver = os.environ["APPROVER_TOKEN"]

original = read_legal_app_name(requester)
print(f"  baseline: legalAppName={original!r}")

test_name = alternate_name(original)
print(f"  test target: legalAppName={test_name!r}")

req_id = request_change(requester, test_name, REASON)
print(f"  OK requestConfigurationChange id={req_id}")

approve_request(approver, req_id)
print("  OK approveRequest (applied)")

assert_name(requester, test_name, "after approve")

revert_id = request_change(requester, original, f"{REASON} (revert)")
print(f"  OK revert request id={revert_id}")

approve_request(approver, revert_id)
print("  OK revert approveRequest (applied)")

assert_name(requester, original, "after revert")

print("")
print("OK: legalAppName 4-eyes E2E smoke passed.")
PY
