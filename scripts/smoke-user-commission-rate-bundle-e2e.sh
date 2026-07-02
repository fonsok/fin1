#!/usr/bin/env bash
# E2E smoke: per-user commission rate bundle 4-eyes (request → approve → verify → revert).
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
TRADER_EMAIL="${SMOKE_TRADER_EMAIL:-trader1@test.com}"
REQUESTER_PASSWORD="${SMOKE_REQUESTER_PASSWORD:-${BA_PASSWORD:-}}"
APPROVER_PASSWORD="${SMOKE_APPROVER_PASSWORD:-${BA_PASSWORD:-}}"
REASON="${SMOKE_USER_COMMISSION_REASON:-E2E smoke: user commission rate bundle 4-eyes test}"

if [ -z "${REQUESTER_PASSWORD}" ] || [ -z "${APPROVER_PASSWORD}" ]; then
  echo "FAIL: REQUESTER/APPROVER password not set." >&2
  echo "  Set BA_PASSWORD or SMOKE_REQUESTER_PASSWORD / SMOKE_APPROVER_PASSWORD in scripts/.env.server" >&2
  exit 2
fi

echo "=== smoke-user-commission-rate-bundle-e2e ==="
echo "  PARSE_URL=$PARSE_URL"
echo "  requester=$REQUESTER_EMAIL approver=$APPROVER_EMAIL trader=$TRADER_EMAIL"

export PARSE_URL APP_ID REASON TRADER_EMAIL REQUESTER_PASSWORD APPROVER_PASSWORD REQUESTER_EMAIL APPROVER_EMAIL

python3 <<'PY'
import json
import os
import subprocess
import sys

PARSE_URL = os.environ["PARSE_URL"]
APP_ID = os.environ["APP_ID"]
REASON = os.environ["REASON"]
TRADER_EMAIL = os.environ["TRADER_EMAIL"].lower()
REQUESTER_EMAIL = os.environ["REQUESTER_EMAIL"]
APPROVER_EMAIL = os.environ["APPROVER_EMAIL"]
REQUESTER_PASSWORD = os.environ["REQUESTER_PASSWORD"]
APPROVER_PASSWORD = os.environ["APPROVER_PASSWORD"]


def curl_json(cmd):
    out = subprocess.check_output(cmd, text=True)
    if not out.strip():
        raise RuntimeError("empty response")
    return json.loads(out)


def login(email, password):
    body = json.dumps({"username": email, "password": password})
    raw = curl_json([
        "curl", "-sk", "--connect-timeout", "15",
        "-X", "POST", f"{PARSE_URL}/login",
        "-H", f"X-Parse-Application-Id: {APP_ID}",
        "-H", "Content-Type: application/json",
        "-d", body,
    ])
    if raw.get("error"):
        raise RuntimeError(f"login {email}: {raw['error']}")
    token = raw.get("sessionToken")
    if not token:
        raise RuntimeError(f"login {email}: no sessionToken")
    return token


def parse_call(fn, body, token):
    cmd = [
        "curl", "-sk", "--connect-timeout", "30",
        "-X", "POST", f"{PARSE_URL}/functions/{fn}",
        "-H", f"X-Parse-Application-Id: {APP_ID}",
        "-H", "Content-Type: application/json",
        "-H", f"X-Parse-Session-Token: {token}",
        "-d", json.dumps(body),
    ]
    raw = curl_json(cmd)
    if raw.get("error"):
        raise RuntimeError(f"{fn}: {raw['error']}")
    return raw.get("result", raw)


def round_rate(n):
    return round(float(n) * 10000) / 10000


def normalize_bundle(raw):
    if not raw:
        return None
    return {
        "investorCommissionRateTotal": round_rate(raw["investorCommissionRateTotal"]),
        "traderCommissionRate": round_rate(raw["traderCommissionRate"]),
        "appCommissionRate": round_rate(raw["appCommissionRate"]),
    }


def resolve_trader_id(token):
    result = parse_call("searchUsers", {"query": TRADER_EMAIL, "limit": 20}, token)
    for user in result.get("users") or []:
        if str(user.get("email", "")).lower() == TRADER_EMAIL:
            user_id = user.get("objectId")
            if user_id:
                return user_id
    raise RuntimeError(f"trader not found: {TRADER_EMAIL}")


def read_commission_controls(token, user_id):
    result = parse_call("getUserDetails", {"userId": user_id}, token)
    controls = result.get("commissionControls") or {}
    return {
        "globalRates": normalize_bundle(controls.get("globalRates")),
        "userOverride": normalize_bundle(controls.get("userOverride")),
        "applicableOverrideRole": controls.get("applicableOverrideRole"),
    }


def alternate_split(bundle):
    total = round_rate(bundle["investorCommissionRateTotal"])
    trader = round_rate(bundle["traderCommissionRate"])
    app = round_rate(bundle["appCommissionRate"])
    step = 0.01
    if trader + step <= total and app - step >= 0:
        new_trader, new_app = round_rate(trader + step), round_rate(app - step)
    elif trader - step >= 0 and app + step <= total:
        new_trader, new_app = round_rate(trader - step), round_rate(app + step)
    else:
        new_trader, new_app = round_rate(total * 0.6), round_rate(total * 0.4)
    if round_rate(new_trader + new_app) != total:
        raise RuntimeError(f"alternate split invalid: {new_trader}+{new_app}!={total}")
    return {
        "investorCommissionRateTotal": total,
        "traderCommissionRate": new_trader,
        "appCommissionRate": new_app,
    }


def request_user_bundle(token, user_id, bundle=None, clear_override=False, reason=REASON):
    body = {"userId": user_id, "reason": reason}
    if clear_override:
        body["clearOverride"] = True
    else:
        body.update(bundle)
    result = parse_call("requestUserCommissionRateBundleChange", body, token)
    if not result.get("success") or not result.get("fourEyesRequestId"):
        raise RuntimeError(f"requestUserCommissionRateBundleChange failed: {result}")
    return result["fourEyesRequestId"]


def approve_request(token, request_id):
    result = parse_call(
        "approveRequest",
        {"requestId": request_id, "notes": "E2E smoke approve"},
        token,
    )
    if not result.get("success") or not result.get("applied"):
        raise RuntimeError(f"approveRequest failed: {result}")


def assert_override(token, user_id, expected, label):
    controls = read_commission_controls(token, user_id)
    actual = controls["userOverride"]
    if expected is None:
        if actual is not None:
            raise RuntimeError(f"{label}: expected no override, got {actual}")
        print(f"  OK {label}: no user override")
        return
    if actual is None:
        raise RuntimeError(f"{label}: expected override {expected}, got null")
    for key, val in expected.items():
        if round_rate(actual[key]) != round_rate(val):
            raise RuntimeError(f"{label}: {key} expected {val}, got {actual[key]}")
    print(
        f"  OK {label}: total={actual['investorCommissionRateTotal']} "
        f"trader={actual['traderCommissionRate']} app={actual['appCommissionRate']}"
    )


requester = login(REQUESTER_EMAIL, REQUESTER_PASSWORD)
print("  OK requester login")
approver = login(APPROVER_EMAIL, APPROVER_PASSWORD)
print("  OK approver login")

trader_id = resolve_trader_id(requester)
print(f"  OK trader id={trader_id}")

baseline = read_commission_controls(requester, trader_id)
if baseline["applicableOverrideRole"] != "trader":
    raise RuntimeError(f"expected trader applicableOverrideRole, got {baseline['applicableOverrideRole']}")

global_rates = baseline["globalRates"]
if not global_rates:
    raise RuntimeError("commissionControls.globalRates missing")

original_override = baseline["userOverride"]
print(
    f"  baseline override: "
    f"{original_override if original_override else 'none'} "
    f"(global total={global_rates['investorCommissionRateTotal']})"
)

base_for_split = original_override or global_rates
test_bundle = alternate_split(base_for_split)
if original_override and test_bundle == original_override:
    test_bundle = alternate_split(global_rates)
if test_bundle == original_override:
    raise RuntimeError("test bundle identical to baseline override; cannot verify change")

print(
    f"  test target: total={test_bundle['investorCommissionRateTotal']} "
    f"trader={test_bundle['traderCommissionRate']} app={test_bundle['appCommissionRate']}"
)

req_id = request_user_bundle(requester, trader_id, test_bundle)
print(f"  OK requestUserCommissionRateBundleChange id={req_id}")

approve_request(approver, req_id)
print("  OK approveRequest (applied)")

assert_override(requester, trader_id, test_bundle, "after approve")

if original_override is None:
    revert_id = request_user_bundle(
        requester,
        trader_id,
        clear_override=True,
        reason=f"{REASON} (revert clear)",
    )
else:
    revert_id = request_user_bundle(
        requester,
        trader_id,
        original_override,
        reason=f"{REASON} (revert)",
    )
print(f"  OK revert request id={revert_id}")

approve_request(approver, revert_id)
print("  OK revert approveRequest (applied)")

assert_override(requester, trader_id, original_override, "after revert")

print("")
print("OK: user commission rate bundle E2E smoke passed.")
PY
