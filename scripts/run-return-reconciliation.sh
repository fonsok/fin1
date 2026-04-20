#!/usr/bin/env bash
set -euo pipefail

# Weekly return-percentage reconciliation wrapper.
# Runs data-quality reconciliation against collection bills.

BASE_DIR="${BASE_DIR:-/home/io/fin1-server}"
BACKEND_DIR="$BASE_DIR/backend"
COMPOSE_FILE="${COMPOSE_FILE:-$BASE_DIR/docker-compose.production.yml}"
SCRIPT_PATH="${SCRIPT_PATH:-$BACKEND_DIR/scripts/weekly-return-percentage-reconciliation.js}"
LOG_FILE="${LOG_FILE:-$BASE_DIR/logs/return-reconciliation.log}"
STATE_FILE="${STATE_FILE:-$BASE_DIR/logs/return-reconciliation.last-run}"
MAX_AGE_SECONDS="${MAX_AGE_SECONDS:-691200}" # 8 days
CATCHUP_MODE="false"

if [[ "${1:-}" == "--catchup" ]]; then
  CATCHUP_MODE="true"
fi

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
epoch_now() { date -u +%s; }

if [[ "$CATCHUP_MODE" == "true" && -f "$STATE_FILE" ]]; then
  LAST_RUN_EPOCH="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
  NOW_EPOCH="$(epoch_now)"
  AGE=$(( NOW_EPOCH - LAST_RUN_EPOCH ))
  if (( AGE >= 0 && AGE < MAX_AGE_SECONDS )); then
    echo "[$(timestamp)] SKIP: reconciliation catch-up not needed (last run ${AGE}s ago, max=${MAX_AGE_SECONDS}s)" >> "$LOG_FILE"
    exit 0
  fi
fi

MONGO_PASSWORD="$(python3 - <<'PY'
from pathlib import Path
env = {}
for raw in Path("/home/io/fin1-server/backend/.env").read_text().splitlines():
    line = raw.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    k, v = line.split("=", 1)
    env[k.strip()] = v
print(env.get("MONGO_INITDB_ROOT_PASSWORD", ""))
PY
)"

if [[ -z "$MONGO_PASSWORD" ]]; then
  echo "[$(timestamp)] ERROR: MONGO_INITDB_ROOT_PASSWORD not found in .env" >> "$LOG_FILE"
  exit 2
fi

{
  echo "[$(timestamp)] START reconciliation"
  cd "$BASE_DIR" && docker compose -f "$COMPOSE_FILE" exec -T mongodb \
    mongosh --quiet --username admin --password "$MONGO_PASSWORD" --authenticationDatabase admin fin1 --eval '
const sampleLimit = 20;
const epsilon = 0.01;
const coll = db.getCollection("Document");
const query = { type: { $in: ["investorCollectionBill", "investor_collection_bill"] }, "metadata.receiptType": { $exists: false } };
const docs = coll.find(query, { projection: { _id: 1, investmentId: 1, tradeId: 1, createdAt: 1, metadata: 1, type: 1 } }).sort({ createdAt: -1 }).limit(5000).toArray();
const byInvestment = new Map();
let missingReturn = 0;
let invalidReturn = 0;
for (const doc of docs) {
  if (!doc.investmentId) continue;
  const ret = doc?.metadata?.returnPercentage;
  if (ret === undefined || ret === null) { missingReturn += 1; continue; }
  if (typeof ret !== "number" || Number.isNaN(ret) || !Number.isFinite(ret)) { invalidReturn += 1; continue; }
  if (!byInvestment.has(doc.investmentId)) byInvestment.set(doc.investmentId, []);
  byInvestment.get(doc.investmentId).push({ returnPercentage: ret, id: doc._id, tradeId: doc.tradeId || null });
}
const drift = [];
for (const [investmentId, rows] of byInvestment.entries()) {
  if (rows.length < 2) continue;
  const values = rows.map((r) => r.returnPercentage);
  const min = Math.min(...values);
  const max = Math.max(...values);
  const spread = max - min;
  if (spread > epsilon) {
    drift.push({ investmentId, docs: rows.length, minReturnPercentage: min, maxReturnPercentage: max, spread, sampleDocIds: rows.slice(0, 3).map((r) => r.id) });
  }
}
print("--- Weekly return% reconciliation ---");
print("checkedDocuments=" + docs.length);
print("investmentsChecked=" + byInvestment.size);
print("missingReturnPercentageCount=" + missingReturn);
print("invalidReturnPercentageCount=" + invalidReturn);
print("driftedInvestmentCount=" + drift.length);
print("healthy=" + (missingReturn === 0 && invalidReturn === 0 && drift.length === 0));
if (drift.length > 0) {
  print("driftSamples(limit=" + sampleLimit + ")=");
  drift.slice(0, sampleLimit).forEach((entry) => printjson(entry));
}
'
  rc=$?
  echo "[$(timestamp)] END reconciliation rc=$rc"
  if [[ $rc -eq 0 ]]; then
    mkdir -p "$(dirname "$STATE_FILE")"
    epoch_now > "$STATE_FILE"
  fi
  exit $rc
} >> "$LOG_FILE" 2>&1
