#!/usr/bin/env bash
# Settlement GL outbox + Statement↔GL reconciliation health (ADR-017 / Phase 4).
#
# Usage:
#   ./scripts/check-settlement-gl-outbox-health.sh
#   REQUIRE_ENABLED=true ./scripts/check-settlement-gl-outbox-health.sh
#   REQUIRE_ENABLED=false ./scripts/check-settlement-gl-outbox-health.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[ -f "$SCRIPT_DIR/.env.server" ] && source "$SCRIPT_DIR/.env.server"

PARSE_HOST="${FIN1_PARSE_CLOUD_SSH_HOST:-${FIN1_SERVER_IP:-192.168.178.20}}"
PARSE_URL="${PARSE_URL:-https://${PARSE_HOST}/parse}"
APP_ID="${PARSE_SERVER_APPLICATION_ID:-fin1-app-id}"
SAMPLE_LIMIT="${SAMPLE_LIMIT:-25}"
RECON_LIMIT="${RECON_LIMIT:-50}"
REQUIRE_ENABLED="${REQUIRE_ENABLED:-}"

load_env_key() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  grep -E "^${key}=" "$file" | head -1 | cut -d= -f2- | tr -d '"' | tr -d "'"
}

ENV_FILE="${FIN1_SERVER_ENV:-$HOME/fin1-server/backend/.env}"
if [ -z "${PARSE_SERVER_MASTER_KEY:-}" ]; then
  PARSE_SERVER_MASTER_KEY="$(load_env_key "$ENV_FILE" PARSE_SERVER_MASTER_KEY || true)"
fi
if [ -z "${PARSE_SERVER_MASTER_KEY:-}" ]; then
  echo "Loading master key from ${FIN1_SERVER_USER:-io}@${PARSE_HOST} …"
  PARSE_SERVER_MASTER_KEY="$(ssh "${FIN1_SERVER_USER:-io}@${PARSE_HOST}" \
    "grep -E '^PARSE_SERVER_MASTER_KEY=' ~/fin1-server/backend/.env | head -1 | cut -d= -f2- | tr -d '\"' | tr -d \"'\"")"
fi
if [ -z "${PARSE_SERVER_MASTER_KEY:-}" ]; then
  echo "Error: PARSE_SERVER_MASTER_KEY not available."
  exit 1
fi

curl_parse() {
  local fn="$1"
  local payload="$2"
  curl -sk --connect-timeout 120 -X POST "${PARSE_URL}/functions/${fn}" \
    -H "X-Parse-Application-Id: ${APP_ID}" \
    -H "X-Parse-Master-Key: ${PARSE_SERVER_MASTER_KEY}" \
    -H "Content-Type: application/json" \
    -d "$payload"
}

echo "=== check-settlement-gl-outbox-health ==="
echo "  PARSE_URL=$PARSE_URL"
echo ""

OUTBOX_RESP="$(curl_parse getSettlementGLOutboxStatus "{\"sampleLimit\":${SAMPLE_LIMIT}}")"
if echo "$OUTBOX_RESP" | grep -q '"error"'; then
  echo "$OUTBOX_RESP" | python3 -m json.tool 2>/dev/null || echo "$OUTBOX_RESP"
  exit 1
fi

RECON_RESP="$(curl_parse getSettlementGLReconciliationStatus "{\"limit\":${RECON_LIMIT}}")"
if echo "$RECON_RESP" | grep -q '"error"'; then
  echo "$RECON_RESP" | python3 -m json.tool 2>/dev/null || echo "$RECON_RESP"
  exit 1
fi

python3 - "$OUTBOX_RESP" "$RECON_RESP" "$REQUIRE_ENABLED" <<'PY'
import json, sys

outbox_raw, recon_raw, require_enabled = sys.argv[1:4]
outbox = json.loads(outbox_raw).get("result", {})
recon = json.loads(recon_raw).get("result", {})

enabled = bool(outbox.get("enabled"))
counts = outbox.get("counts") or {}
pending = int(counts.get("pending") or 0)
processing = int(counts.get("processing") or 0)
posted = int(counts.get("posted") or 0)
failed = int(counts.get("failed") or 0)

overall = str(recon.get("overall") or "unknown")
violations = int(recon.get("violationCount") or 0)

print("Outbox:")
print(f"  enabled={enabled}")
print(f"  pending={pending} processing={processing} posted={posted} failed={failed}")
if outbox.get("samples"):
    print("  samples:")
    for row in outbox["samples"][:5]:
        print(f"    - {row.get('id')} status={row.get('status')} trade={row.get('tradeId')} err={row.get('lastError')}")

print("")
print("Reconciliation:")
print(f"  overall={overall}")
print(f"  checked_trades={recon.get('checkedTrades', 0)} violation_count={violations}")
if recon.get("repairHint"):
    print(f"  repair_hint={recon['repairHint']}")

issues = []
if require_enabled == "true" and not enabled:
    issues.append("settlementGLOutboxEnabled is false but REQUIRE_ENABLED=true")
if require_enabled == "false" and enabled:
    issues.append("settlementGLOutboxEnabled is true but REQUIRE_ENABLED=false")
if failed > 0:
    issues.append(f"failed outbox rows={failed}")
if pending > 0 or processing > 0:
    issues.append(f"outbox backlog pending={pending} processing={processing}")
if overall not in ("healthy", "unknown"):
    issues.append(f"reconciliation overall={overall}")
if violations > 0:
    issues.append(f"reconciliation violations={violations}")

print("")
if issues:
    print("UNHEALTHY:")
    for item in issues:
        print(f"  - {item}")
    print("")
    print("Repair hints:")
    if failed > 0 or pending > 0 or processing > 0:
        print("  ./scripts/run-settlement-gl-outbox-drain.sh")
        print("  or: runSettlementGLOutbox / postSettlementGLFromOutbox (admin)")
    if violations > 0:
        print("  backfillMissingSettlementGL({ dryRun: true })")
    sys.exit(2)

print("OK: outbox queue drained and GL reconciliation healthy.")
PY
