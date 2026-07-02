#!/usr/bin/env bash
# E2E smoke: server market-data feed → MarketData → executePairedBuy (no upsertMarketDataQuote).
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
ADMIN_EMAIL="${SMOKE_REQUESTER_EMAIL:-admin@fin1.de}"
ADMIN_PASSWORD="${SMOKE_REQUESTER_PASSWORD:-${BA_PASSWORD:-}}"
TRADER_EMAIL="${SMOKE_TRADER_EMAIL:-trader1@test.com}"
TRADER_PASSWORD="${SMOKE_TRADER_PASSWORD:-TestPassword123!}"
FEED_SYMBOL="${SMOKE_MARKET_DATA_FEED_SYMBOL:-865985}"

if [ -z "${ADMIN_PASSWORD}" ] || [ -z "${TRADER_PASSWORD}" ]; then
  echo "FAIL: admin/trader password not set." >&2
  exit 2
fi

echo "=== smoke-market-data-feed-e2e ==="
echo "  PARSE_URL=$PARSE_URL"
echo "  feedSymbol=$FEED_SYMBOL"

export PARSE_URL APP_ID ADMIN_EMAIL ADMIN_PASSWORD TRADER_EMAIL TRADER_PASSWORD FEED_SYMBOL

python3 <<'PY'
import json
import os
import random
import subprocess
import time

PARSE_URL = os.environ["PARSE_URL"]
APP_ID = os.environ["APP_ID"]
ADMIN_EMAIL = os.environ["ADMIN_EMAIL"]
ADMIN_PASSWORD = os.environ["ADMIN_PASSWORD"]
TRADER_EMAIL = os.environ["TRADER_EMAIL"]
TRADER_PASSWORD = os.environ["TRADER_PASSWORD"]
FEED_SYMBOL = os.environ["FEED_SYMBOL"]


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
    raw = curl_json([
        "curl", "-sk", "--connect-timeout", "45",
        "-X", "POST", f"{PARSE_URL}/functions/{fn}",
        "-H", f"X-Parse-Application-Id: {APP_ID}",
        "-H", "Content-Type: application/json",
        "-H", f"X-Parse-Session-Token: {token}",
        "-d", json.dumps(body),
    ])
    if raw.get("error"):
        raise RuntimeError(f"{fn}: {raw['error']}")
    return raw.get("result", raw)


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


def latest_market_data_price(symbol, token):
    where = json.dumps({"symbol": symbol})
    raw = curl_json([
        "curl", "-sk", "--connect-timeout", "15",
        "-G", f"{PARSE_URL}/classes/MarketData",
        "-H", f"X-Parse-Application-Id: {APP_ID}",
        "-H", f"X-Parse-Session-Token: {token}",
        "--data-urlencode", f"where={where}",
        "--data-urlencode", "order=-timestamp",
        "--data-urlencode", "limit=1",
    ])
    rows = raw.get("results") or []
    if not rows:
        return None
    return float(rows[0].get("price") or 0)


admin = login(ADMIN_EMAIL, ADMIN_PASSWORD)
print("  OK admin login")

feed = parse_call(
    "runMarketDataFeedRefresh",
    {"symbols": [FEED_SYMBOL]},
    admin,
)
if not feed.get("enabled") or int(feed.get("refreshed") or 0) < 1:
    raise RuntimeError(f"runMarketDataFeedRefresh failed: {feed}")
print(f"  OK runMarketDataFeedRefresh refreshed={feed['refreshed']}")

trader = login(TRADER_EMAIL, TRADER_PASSWORD)
print("  OK trader login")

price = latest_market_data_price(FEED_SYMBOL, trader)
if not price or price <= 0:
    raise RuntimeError(f"no MarketData row for {FEED_SYMBOL}")
print(f"  OK MarketData present price={price}")

intent_id = f"smoke-feed-{int(time.time())}-{random.randint(1000, 9999)}"
body = {
    "symbol": FEED_SYMBOL,
    "orderInstruction": "market",
    "clientOrderIntentId": intent_id,
    "traderQuantity": 1,
    "mirrorPoolQuantity": 0,
    "description": "smoke market data feed E2E",
}
raw = parse_call_raw("executePairedBuy", body, trader)
if raw.get("error"):
    err = str(raw.get("error") or "")
    if "no market data" in err.lower() or "stale" in err.lower():
        raise RuntimeError(f"executePairedBuy still missing feed quote: {err}")
    if "Mindest-Kaufbetrag" in err or "Mindest-Kauf" in err:
        print("  OK executePairedBuy resolved feed MarketData (blocked on min buy)")
    else:
        raise RuntimeError(f"unexpected executePairedBuy error: {err}")
else:
    print("  OK executePairedBuy succeeded using feed-only MarketData")

print("")
print("OK: market data feed E2E smoke passed.")
PY
