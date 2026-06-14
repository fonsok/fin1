#!/usr/bin/env bash
# E2E smoke: commission rate bundle 4-eyes (request → approve → verify → revert).
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
REASON="${SMOKE_COMMISSION_REASON:-E2E smoke: commission rate bundle 4-eyes test}"

if [ -z "${REQUESTER_PASSWORD}" ] || [ -z "${APPROVER_PASSWORD}" ]; then
  echo "FAIL: REQUESTER/APPROVER password not set." >&2
  echo "  Set BA_PASSWORD or SMOKE_REQUESTER_PASSWORD / SMOKE_APPROVER_PASSWORD in scripts/.env.server" >&2
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

echo "=== smoke-commission-rate-bundle-e2e ==="
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


def round_rate(n):
    return round(float(n) * 10000) / 10000


def read_bundle(token):
    cfg = parse_call("getConfiguration", {}, token)
    fin = cfg.get("financial") or {}
    return {
        "investorCommissionRateTotal": round_rate(fin["investorCommissionRateTotal"]),
        "traderCommissionRate": round_rate(fin["traderCommissionRate"]),
        "appCommissionRate": round_rate(fin["appCommissionRate"]),
    }


def assert_bundle(token, expected, label):
    actual = read_bundle(token)
    for key, val in expected.items():
        if round_rate(actual[key]) != round_rate(val):
            raise RuntimeError(
                f"{label}: {key} expected {val}, got {actual[key]} (full={actual})"
            )
    print(f"  OK {label}: total={actual['investorCommissionRateTotal']} "
          f"trader={actual['traderCommissionRate']} app={actual['appCommissionRate']}")


def alternate_split(bundle):
    total = round_rate(bundle["investorCommissionRateTotal"])
    trader = round_rate(bundle["traderCommissionRate"])
    app = round_rate(bundle["appCommissionRate"])
    if total <= 0:
        raise RuntimeError("Cannot alternate split: total commission is 0")
    step = 0.01
    if trader + step <= total and app - step >= 0:
        new_trader, new_app = round_rate(trader + step), round_rate(app - step)
    elif trader - step >= 0 and app + step <= total:
        new_trader, new_app = round_rate(trader - step), round_rate(app + step)
    else:
        new_trader, new_app = round_rate(total * 0.6), round_rate(total * 0.4)
    if round_rate(new_trader + new_app) != total:
        raise RuntimeError(f"Alternate split invalid: {new_trader}+{new_app}!={total}")
    return {
        "investorCommissionRateTotal": total,
        "traderCommissionRate": new_trader,
        "appCommissionRate": new_app,
    }


def request_bundle(token, bundle, reason):
    body = {**bundle, "reason": reason}
    result = parse_call("requestCommissionRateBundleChange", body, token)
    if not result.get("success") or not result.get("fourEyesRequestId"):
        raise RuntimeError(f"requestCommissionRateBundleChange failed: {result}")
    return result["fourEyesRequestId"]


def approve_request(token, request_id):
    result = parse_call("approveRequest", {"requestId": request_id, "notes": "E2E smoke approve"}, token)
    if not result.get("success") or not result.get("applied"):
        raise RuntimeError(f"approveRequest failed: {result}")
    return result


requester = os.environ["REQUESTER_TOKEN"]
approver = os.environ["APPROVER_TOKEN"]

original = read_bundle(requester)
print(f"  baseline: total={original['investorCommissionRateTotal']} "
      f"trader={original['traderCommissionRate']} app={original['appCommissionRate']}")

test_bundle = alternate_split(original)
if test_bundle == original:
    raise RuntimeError("Test bundle identical to baseline; cannot verify change")

print(f"  test target: total={test_bundle['investorCommissionRateTotal']} "
      f"trader={test_bundle['traderCommissionRate']} app={test_bundle['appCommissionRate']}")

req_id = request_bundle(requester, test_bundle, REASON)
print(f"  OK requestCommissionRateBundleChange id={req_id}")

approve_request(approver, req_id)
print("  OK approveRequest (applied)")

assert_bundle(requester, test_bundle, "after approve")

revert_id = request_bundle(
    requester,
    original,
    f"{REASON} (revert)",
)
print(f"  OK revert request id={revert_id}")

approve_request(approver, revert_id)
print("  OK revert approveRequest (applied)")

assert_bundle(requester, original, "after revert")

print("")
print("OK: commission rate bundle E2E smoke passed.")
PY
