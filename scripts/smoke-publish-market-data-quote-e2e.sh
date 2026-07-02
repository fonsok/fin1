#!/usr/bin/env bash
# E2E smoke: trader upsertMarketDataQuote → executePairedBuy resolves MarketData (no master-key seed).
# Proves ADR-019 Phase 8 interim path without direct POST /classes/MarketData.
#
# Requires BA_PASSWORD or SMOKE_TRADER_PASSWORD in scripts/.env.server.
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
TRADER_EMAIL="${SMOKE_TRADER_EMAIL:-trader1@test.com}"
TRADER_PASSWORD="${SMOKE_TRADER_PASSWORD:-TestPassword123!}"

if [ -z "${TRADER_PASSWORD}" ]; then
  echo "FAIL: trader password not set (SMOKE_TRADER_PASSWORD or BA_PASSWORD)." >&2
  exit 2
fi

echo "=== smoke-publish-market-data-quote-e2e ==="
echo "  PARSE_URL=$PARSE_URL"
echo "  trader=$TRADER_EMAIL"

export PARSE_URL APP_ID TRADER_EMAIL TRADER_PASSWORD

python3 <<'PY'
import json
import os
import random
import subprocess
import time

PARSE_URL = os.environ["PARSE_URL"]
APP_ID = os.environ["APP_ID"]
TRADER_EMAIL = os.environ["TRADER_EMAIL"].lower()
TRADER_PASSWORD = os.environ["TRADER_PASSWORD"]
SYMBOL = f"SMOKE-PUB-MD-{int(time.time())}-{random.randint(1000, 9999)}"
QUOTE_PRICE = 100.0


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


def execute_paired_buy_raw(token, intent_id):
    body = {
        "symbol": SYMBOL,
        "orderInstruction": "market",
        "clientOrderIntentId": intent_id,
        "traderQuantity": 1,
        "mirrorPoolQuantity": 0,
        "description": "smoke upsertMarketDataQuote E2E",
    }
    return parse_call_raw("executePairedBuy", body, token)


trader = login(TRADER_EMAIL, TRADER_PASSWORD)
print("  OK trader login")
print(f"  symbol={SYMBOL} (unique, no pre-seeded MarketData)")

# --- without publish: must fail on missing MarketData ---
before_intent = f"smoke-pub-md-before-{int(time.time())}"
before_raw = execute_paired_buy_raw(trader, before_intent)
if not before_raw.get("error"):
    raise RuntimeError("expected executePairedBuy to fail without MarketData")
before_err = str(before_raw.get("error") or "")
if "no market data" not in before_err.lower():
    raise RuntimeError(f"expected no market data error, got: {before_err}")
print("  OK executePairedBuy blocked without MarketData")

# --- publish via Cloud Function (trader session, no master key) ---
published = parse_call(
    "upsertMarketDataQuote",
    {"symbol": SYMBOL, "price": QUOTE_PRICE},
    trader,
)
if published.get("symbol") != SYMBOL:
    raise RuntimeError(f"upsertMarketDataQuote symbol mismatch: {published}")
if abs(float(published.get("price", 0)) - QUOTE_PRICE) > 1e-4:
    raise RuntimeError(f"upsertMarketDataQuote price mismatch: {published}")
if not published.get("publishedAt"):
    raise RuntimeError(f"upsertMarketDataQuote missing publishedAt: {published}")
print(f"  OK upsertMarketDataQuote price={published['price']}")

# --- after publish: price resolver must find MarketData (min-buy block, not missing data) ---
after_intent = f"smoke-pub-md-after-{int(time.time())}"
after_raw = execute_paired_buy_raw(trader, after_intent)
if not after_raw.get("error"):
    raise RuntimeError(
        "expected executePairedBuy to fail on min buy (qty=1 @ 100), not succeed without cleanup"
    )
after_err = str(after_raw.get("error") or "")
if "no market data" in after_err.lower() or "stale" in after_err.lower():
    raise RuntimeError(f"MarketData still not resolved after publish: {after_err}")
if "Mindest-Kaufbetrag" not in after_err and "Mindest-Kauf" not in after_err:
    raise RuntimeError(f"expected min-buy enforcement after quote publish, got: {after_err}")
print("  OK executePairedBuy resolved MarketData (blocked on min buy, not missing quote)")

print("")
print("OK: upsertMarketDataQuote E2E smoke passed.")
PY
