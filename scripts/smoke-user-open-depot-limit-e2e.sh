#!/usr/bin/env bash
# E2E smoke: per-trader open depot position limit (4-eyes + executePairedBuy block).
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
TRADER_EMAIL="${SMOKE_TRADER_EMAIL:-trader2@test.com}"
TRADER_PASSWORD="${SMOKE_TRADER_PASSWORD:-TestPassword123!}"
REQUESTER_PASSWORD="${SMOKE_REQUESTER_PASSWORD:-${BA_PASSWORD:-}}"
APPROVER_PASSWORD="${SMOKE_APPROVER_PASSWORD:-${BA_PASSWORD:-}}"
REASON="${SMOKE_USER_OPEN_DEPOT_LIMIT_REASON:-E2E smoke: user open depot limit 4-eyes test}"

if [ -z "${REQUESTER_PASSWORD}" ] || [ -z "${APPROVER_PASSWORD}" ]; then
  echo "FAIL: REQUESTER/APPROVER password not set." >&2
  echo "  Set BA_PASSWORD or SMOKE_REQUESTER_PASSWORD / SMOKE_APPROVER_PASSWORD in scripts/.env.server" >&2
  exit 2
fi

echo "=== smoke-user-open-depot-limit-e2e ==="
echo "  PARSE_URL=$PARSE_URL"
echo "  requester=$REQUESTER_EMAIL approver=$APPROVER_EMAIL trader=$TRADER_EMAIL"

export PARSE_URL APP_ID REASON TRADER_EMAIL TRADER_PASSWORD \
  REQUESTER_PASSWORD APPROVER_PASSWORD REQUESTER_EMAIL APPROVER_EMAIL

python3 <<'PY'
import json
import os
import random
import subprocess
import time
from datetime import datetime, timezone

PARSE_URL = os.environ["PARSE_URL"]
APP_ID = os.environ["APP_ID"]
REASON = os.environ["REASON"]
TRADER_EMAIL = os.environ["TRADER_EMAIL"].lower()
TRADER_PASSWORD = os.environ["TRADER_PASSWORD"]
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


def parse_call_raw(fn, body, token):
    cmd = [
        "curl", "-sk", "--connect-timeout", "45",
        "-X", "POST", f"{PARSE_URL}/functions/{fn}",
        "-H", f"X-Parse-Application-Id: {APP_ID}",
        "-H", "Content-Type: application/json",
        "-H", f"X-Parse-Session-Token: {token}",
        "-d", json.dumps(body),
    ]
    return curl_json(cmd)


def parse_call(fn, body, token):
    raw = parse_call_raw(fn, body, token)
    if raw.get("error"):
        raise RuntimeError(f"{fn}: {raw['error']}")
    return raw.get("result", raw)


def resolve_trader_id(token):
    result = parse_call("searchUsers", {"query": TRADER_EMAIL, "limit": 20}, token)
    for user in result.get("users") or []:
        if str(user.get("email", "")).lower() == TRADER_EMAIL:
            user_id = user.get("objectId")
            if user_id:
                return user_id
    raise RuntimeError(f"trader not found: {TRADER_EMAIL}")


def read_open_depot_controls(token, user_id):
    result = parse_call("getUserDetails", {"userId": user_id}, token)
    controls = result.get("openDepotLimitControls") or {}
    return {
        "globalLimit": int(controls.get("globalLimit") or 0),
        "storedOverride": controls.get("storedOverride"),
        "userOverride": controls.get("userOverride"),
        "effectiveLimit": int(controls.get("effectiveLimit") or 0),
        "openDepotPositions": int(controls.get("openDepotPositions") or 0),
        "applicable": controls.get("applicable"),
        "source": controls.get("source"),
    }


def alternate_limit(global_limit, current_override):
    base = int(current_override) if current_override is not None else int(global_limit)
    if base < 50:
        return base + 1
    if base > 1:
        return base - 1
    return 5


def request_user_limit(token, user_id, limit=None, clear_override=False, reason=REASON):
    body = {"userId": user_id, "reason": reason}
    if clear_override:
        body["clearOverride"] = True
    else:
        body["maxOpenDepotPositions"] = int(limit)
    result = parse_call("requestUserOpenDepotLimitChange", body, token)
    if not result.get("success") or not result.get("fourEyesRequestId"):
        raise RuntimeError(f"requestUserOpenDepotLimitChange failed: {result}")
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
    controls = read_open_depot_controls(token, user_id)
    actual = controls["storedOverride"]
    if expected is None:
        if actual is not None:
            raise RuntimeError(f"{label}: expected no stored override, got {actual}")
        print(f"  OK {label}: no stored override")
        return
    if actual is None:
        raise RuntimeError(f"{label}: expected stored override {expected}, got null")
    if int(actual) != int(expected):
        raise RuntimeError(f"{label}: expected {expected}, got {actual}")
    print(f"  OK {label}: stored override={actual}")


def iso_quote_now():
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def parse_master_key():
    for key in ("PARSE_MASTER_KEY", "PARSE_SERVER_MASTER_KEY"):
        value = os.environ.get(key, "").strip()
        if value:
            return value
    return None


def ensure_market_data(symbol, price, session_token=None):
    body = json.dumps({
        "symbol": symbol,
        "price": float(price),
        "exchange": "SMOKE",
        "timestamp": {"__type": "Date", "iso": iso_quote_now()},
    })
    cmd = [
        "curl", "-sk", "--connect-timeout", "15",
        "-X", "POST", f"{PARSE_URL}/classes/MarketData",
        "-H", f"X-Parse-Application-Id: {APP_ID}",
        "-H", "Content-Type: application/json",
    ]
    master_key = parse_master_key()
    if master_key:
        cmd.extend(["-H", f"X-Parse-Master-Key: {master_key}"])
    elif session_token:
        cmd.extend(["-H", f"X-Parse-Session-Token: {session_token}"])
    else:
        raise RuntimeError("MarketData seed requires PARSE_MASTER_KEY or session token")
    cmd.extend(["-d", body])
    raw = curl_json(cmd)
    if raw.get("error"):
        raise RuntimeError(f"MarketData seed failed for {symbol}: {raw['error']}")


def publish_market_quote(trader_token, symbol, price):
    result = parse_call(
        "upsertMarketDataQuote",
        {"symbol": symbol, "price": float(price)},
        trader_token,
    )
    if not result.get("symbol"):
        raise RuntimeError(f"upsertMarketDataQuote failed for {symbol}: {result}")


def execute_paired_buy(trader_token, intent_id=None, market_price=100.0, trader_quantity=3):
    publish_market_quote(trader_token, "SMOKE-DEPOT-LIMIT-WKN", market_price)
    intent_id = intent_id or f"smoke-depot-limit-{int(time.time())}-{random.randint(1000, 9999)}"
    body = {
        "symbol": "SMOKE-DEPOT-LIMIT-WKN",
        "orderInstruction": "market",
        "clientOrderIntentId": intent_id,
        "traderQuantity": int(trader_quantity),
        "mirrorPoolQuantity": 0,
        "description": "smoke open depot limit E2E",
    }
    return intent_id, parse_call_raw("executePairedBuy", body, trader_token)


def finalize_paired_buy(token, pair_execution_id):
    result = parse_call(
        "finalizePairedBuyExecution",
        {"pairExecutionId": pair_execution_id},
        token,
    )
    if not result:
        raise RuntimeError("finalizePairedBuyExecution returned empty result")
    return result


def ensure_one_open_position(admin_token, trader_token, trader_id):
    controls = read_open_depot_controls(admin_token, trader_id)
    open_count = controls["openDepotPositions"]
    if open_count >= 1:
        print(f"  OK trader already has {open_count} open depot position(s)")
        return open_count

    print("  creating one open depot position via paired buy …")
    intent_id, raw = execute_paired_buy(trader_token)
    if raw.get("error"):
        raise RuntimeError(f"executePairedBuy (seed position) failed: {raw['error']}")
    pair_id = (raw.get("result") or {}).get("pairExecutionId")
    if not pair_id:
        raise RuntimeError(f"executePairedBuy missing pairExecutionId: {raw}")
    finalize_paired_buy(trader_token, pair_id)
    print(f"  OK seeded position pairExecutionId={pair_id} intent={intent_id}")

    controls = read_open_depot_controls(admin_token, trader_id)
    open_count = controls["openDepotPositions"]
    if open_count < 1:
        raise RuntimeError(f"expected openDepotPositions >= 1 after seed, got {open_count}")
    print(f"  OK open depot positions after seed: {open_count}")
    return open_count


def assert_paired_buy_blocked(trader_token):
    _, raw = execute_paired_buy(trader_token)
    if not raw.get("error"):
        raise RuntimeError("expected executePairedBuy to fail at depot limit, but succeeded")
    err = str(raw.get("error") or "")
    code = raw.get("code")
    if "offene Depot-Position" not in err and "Depot-Position" not in err:
        raise RuntimeError(f"unexpected executePairedBuy error (code={code}): {err}")
    print(f"  OK executePairedBuy blocked: {err[:120]}…" if len(err) > 120 else f"  OK executePairedBuy blocked: {err}")


# --- Part 1: 4-eyes override roundtrip ---
requester = login(REQUESTER_EMAIL, REQUESTER_PASSWORD)
print("  OK requester login")
approver = login(APPROVER_EMAIL, APPROVER_PASSWORD)
print("  OK approver login")

trader_id = resolve_trader_id(requester)
print(f"  OK trader id={trader_id}")

baseline = read_open_depot_controls(requester, trader_id)
if not baseline["applicable"]:
    raise RuntimeError("expected trader openDepotLimitControls.applicable=true")

global_limit = baseline["globalLimit"]
if global_limit < 1:
    raise RuntimeError(f"openDepotLimitControls.globalLimit invalid: {global_limit}")

original_override = baseline["storedOverride"]
print(
    f"  baseline stored override: "
    f"{original_override if original_override is not None else 'none'} "
    f"(global={global_limit}, open={baseline['openDepotPositions']})"
)

test_limit = alternate_limit(global_limit, original_override)
if original_override is not None and int(test_limit) == int(original_override):
    test_limit = alternate_limit(global_limit, None)
if original_override is not None and int(test_limit) == int(original_override):
    raise RuntimeError("test limit identical to baseline override; cannot verify change")

print(f"  test target override: {test_limit} positions")

req_id = request_user_limit(requester, trader_id, test_limit)
print(f"  OK requestUserOpenDepotLimitChange id={req_id}")

approve_request(approver, req_id)
print("  OK approveRequest (applied)")

assert_stored_override(requester, trader_id, test_limit, "after approve")

if original_override is None:
    revert_id = request_user_limit(
        requester,
        trader_id,
        clear_override=True,
        reason=f"{REASON} (revert clear)",
    )
else:
    revert_id = request_user_limit(
        requester,
        trader_id,
        original_override,
        reason=f"{REASON} (revert)",
    )
print(f"  OK revert request id={revert_id}")

approve_request(approver, revert_id)
print("  OK revert approveRequest (applied)")

assert_stored_override(requester, trader_id, original_override, "after revert")

# --- Part 2: executePairedBuy enforcement at limit ---
print("")
print("  --- enforcement: executePairedBuy at open-count limit ---")

trader_token = login(TRADER_EMAIL, TRADER_PASSWORD)
print("  OK trader login")

open_count = ensure_one_open_position(requester, trader_token, trader_id)
cap_limit = open_count
print(f"  setting override to open count ({cap_limit}) to cap further buys …")

controls_before_cap = read_open_depot_controls(requester, trader_id)
if controls_before_cap.get("storedOverride") is not None and int(controls_before_cap["storedOverride"]) == int(cap_limit):
    print(f"  OK cap override already at {cap_limit} — skip request")
else:
    cap_req_id = request_user_limit(
        requester,
        trader_id,
        cap_limit,
        reason=f"{REASON} (enforce cap at open={cap_limit})",
    )
    approve_request(approver, cap_req_id)
    print(f"  OK cap override approved id={cap_req_id}")

controls = read_open_depot_controls(requester, trader_id)
if int(controls["effectiveLimit"]) != cap_limit:
    raise RuntimeError(
        f"effectiveLimit expected {cap_limit}, got {controls['effectiveLimit']} (source={controls['source']})"
    )
print(f"  OK effectiveLimit={controls['effectiveLimit']} source={controls['source']}")

assert_paired_buy_blocked(trader_token)

controls_after_enforce = read_open_depot_controls(requester, trader_id)
current_override = controls_after_enforce.get("storedOverride")
needs_enforce_revert = (
    original_override is None and current_override is not None
) or (
    original_override is not None
    and (current_override is None or int(current_override) != int(original_override))
)

if not needs_enforce_revert:
    print("  OK enforcement cleanup: override already at baseline")
else:
    if original_override is None:
        enforce_revert_id = request_user_limit(
            requester,
            trader_id,
            clear_override=True,
            reason=f"{REASON} (enforce revert clear)",
        )
    else:
        enforce_revert_id = request_user_limit(
            requester,
            trader_id,
            original_override,
            reason=f"{REASON} (enforce revert)",
        )
    approve_request(approver, enforce_revert_id)
    print(f"  OK enforcement revert approved id={enforce_revert_id}")

assert_stored_override(requester, trader_id, original_override, "after enforcement revert")

print("")
print("OK: user open depot limit E2E smoke passed.")
PY
