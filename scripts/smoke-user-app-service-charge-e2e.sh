#!/usr/bin/env bash
# E2E smoke: per-investor App Service Charge 4-eyes (request → approve → verify → revert).
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
INVESTOR_EMAIL="${SMOKE_INVESTOR_EMAIL:-investor5@test.com}"
REQUESTER_PASSWORD="${SMOKE_REQUESTER_PASSWORD:-${BA_PASSWORD:-}}"
APPROVER_PASSWORD="${SMOKE_APPROVER_PASSWORD:-${BA_PASSWORD:-}}"
REASON="${SMOKE_USER_APP_SERVICE_CHARGE_REASON:-E2E smoke: user app service charge 4-eyes test}"

if [ -z "${REQUESTER_PASSWORD}" ] || [ -z "${APPROVER_PASSWORD}" ]; then
  echo "FAIL: REQUESTER/APPROVER password not set." >&2
  echo "  Set BA_PASSWORD or SMOKE_REQUESTER_PASSWORD / SMOKE_APPROVER_PASSWORD in scripts/.env.server" >&2
  exit 2
fi

echo "=== smoke-user-app-service-charge-e2e ==="
echo "  PARSE_URL=$PARSE_URL"
echo "  requester=$REQUESTER_EMAIL approver=$APPROVER_EMAIL investor=$INVESTOR_EMAIL"

export PARSE_URL APP_ID REASON INVESTOR_EMAIL REQUESTER_PASSWORD APPROVER_PASSWORD REQUESTER_EMAIL APPROVER_EMAIL

python3 <<'PY'
import json
import os
import subprocess

PARSE_URL = os.environ["PARSE_URL"]
APP_ID = os.environ["APP_ID"]
REASON = os.environ["REASON"]
INVESTOR_EMAIL = os.environ["INVESTOR_EMAIL"].lower()
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


def normalize_rate(raw):
    if raw is None:
        return None
    return round_rate(raw)


def resolve_investor_id(token):
    result = parse_call("searchUsers", {"query": INVESTOR_EMAIL, "limit": 20}, token)
    for user in result.get("users") or []:
        if str(user.get("email", "")).lower() == INVESTOR_EMAIL:
            user_id = user.get("objectId")
            if user_id:
                return user_id
    raise RuntimeError(f"investor not found: {INVESTOR_EMAIL}")


def read_app_service_charge_controls(token, user_id):
    result = parse_call("getUserDetails", {"userId": user_id}, token)
    controls = result.get("appServiceChargeControls") or {}
    return {
        "globalRate": normalize_rate(controls.get("globalRate")),
        "storedOverride": normalize_rate(controls.get("storedOverride")),
        "userOverride": normalize_rate(controls.get("userOverride")),
        "applicable": controls.get("applicable"),
    }


def alternate_rate(global_rate, current_override):
    base = current_override if current_override is not None else global_rate
    step = 0.005
    if base + step <= 0.1:
        return round_rate(base + step)
    if base - step >= 0:
        return round_rate(base - step)
    raise RuntimeError(f"cannot derive alternate rate from base={base}")


def request_user_rate(token, user_id, rate=None, clear_override=False, reason=REASON):
    body = {"userId": user_id, "reason": reason}
    if clear_override:
        body["clearOverride"] = True
    else:
        body["appServiceChargeRate"] = rate
    result = parse_call("requestUserAppServiceChargeChange", body, token)
    if not result.get("success") or not result.get("fourEyesRequestId"):
        raise RuntimeError(f"requestUserAppServiceChargeChange failed: {result}")
    return result["fourEyesRequestId"]


def approve_request(token, request_id):
    result = parse_call(
        "approveRequest",
        {"requestId": request_id, "notes": "E2E smoke approve"},
        token,
    )
    if not result.get("success") or not result.get("applied"):
        raise RuntimeError(f"approveRequest failed: {result}")


def assert_stored_override(token, user_id, expected, label):
    controls = read_app_service_charge_controls(token, user_id)
    actual = controls["storedOverride"]
    if expected is None:
        if actual is not None:
            raise RuntimeError(f"{label}: expected no stored override, got {actual}")
        print(f"  OK {label}: no stored override")
        return
    if actual is None:
        raise RuntimeError(f"{label}: expected stored override {expected}, got null")
    if round_rate(actual) != round_rate(expected):
        raise RuntimeError(f"{label}: expected {expected}, got {actual}")
    print(f"  OK {label}: stored override={actual}")


requester = login(REQUESTER_EMAIL, REQUESTER_PASSWORD)
print("  OK requester login")
approver = login(APPROVER_EMAIL, APPROVER_PASSWORD)
print("  OK approver login")

investor_id = resolve_investor_id(requester)
print(f"  OK investor id={investor_id}")

baseline = read_app_service_charge_controls(requester, investor_id)
if not baseline["applicable"]:
    raise RuntimeError("expected investor appServiceChargeControls.applicable=true")

global_rate = baseline["globalRate"]
if global_rate is None:
    raise RuntimeError("appServiceChargeControls.globalRate missing")

original_override = baseline["storedOverride"]
print(
    f"  baseline stored override: "
    f"{original_override if original_override is not None else 'none'} "
    f"(global={global_rate})"
)

test_rate = alternate_rate(global_rate, original_override)
if original_override is not None and round_rate(test_rate) == round_rate(original_override):
    test_rate = alternate_rate(global_rate, None)
if original_override is not None and round_rate(test_rate) == round_rate(original_override):
    raise RuntimeError("test rate identical to baseline override; cannot verify change")

print(f"  test target: {test_rate}")

req_id = request_user_rate(requester, investor_id, test_rate)
print(f"  OK requestUserAppServiceChargeChange id={req_id}")

approve_request(approver, req_id)
print("  OK approveRequest (applied)")

assert_stored_override(requester, investor_id, test_rate, "after approve")

if original_override is None:
    revert_id = request_user_rate(
        requester,
        investor_id,
        clear_override=True,
        reason=f"{REASON} (revert clear)",
    )
else:
    revert_id = request_user_rate(
        requester,
        investor_id,
        original_override,
        reason=f"{REASON} (revert)",
    )
print(f"  OK revert request id={revert_id}")

approve_request(approver, revert_id)
print("  OK revert approveRequest (applied)")

assert_stored_override(requester, investor_id, original_override, "after revert")

print("")
print("OK: user app service charge E2E smoke passed.")
PY
