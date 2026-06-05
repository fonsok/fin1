#!/usr/bin/env bash
# Renames legacy AppLedgerEntry.account CLT-LIAB-TRD → CLT-LIAB-PTR (SKR 1592 unchanged).
# Business refs like TRD-{tradeNumber} are NOT touched.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "${ROOT}/scripts/.env.server" 2>/dev/null || true

MONGO_HOST="${FIN1_MONGO_HOST:-192.168.178.24}"
MONGO_DB="${FIN1_MONGO_DB:-fin1}"
DRY_RUN="${DRY_RUN:-1}"

FROM_ACCOUNT="CLT-LIAB-TRD"
TO_ACCOUNT="CLT-LIAB-PTR"
FROM_MAPPING="SKR03:2026-05-v1:${FROM_ACCOUNT}"
TO_MAPPING="SKR03:2026-05-v1:${TO_ACCOUNT}"

echo "Host: ${MONGO_HOST} DB: ${MONGO_DB} DRY_RUN=${DRY_RUN}"

if ! command -v mongosh >/dev/null 2>&1; then
  REMOTE_USER="${FIN1_SERVER_USER:-io}"
  REMOTE_HOST="${FIN1_MONGO_SSH_HOST:-${MONGO_HOST}}"
  echo "▸ local mongosh missing — running on ${REMOTE_USER}@${REMOTE_HOST} via docker …"
  ssh "${REMOTE_USER}@${REMOTE_HOST}" bash -s "$DRY_RUN" <<'REMOTE'
DRY="$1"
cd ~/fin1-server
MONGO_PASSWORD=$(grep -E '^MONGO_INITDB_ROOT_PASSWORD=' .env | tail -1 | cut -d= -f2- | tr -d '"' | tr -d "'")
docker compose -f docker-compose.production.yml exec -T mongodb mongosh --quiet \
  -u admin -p "$MONGO_PASSWORD" --authenticationDatabase admin fin1 \
  --eval "
const from='CLT-LIAB-TRD';
const to='CLT-LIAB-PTR';
const n=db.AppLedgerEntry.countDocuments({account:from});
print('Rows with account '+from+': '+n);
if (Number('$DRY')===1){ print('DRY_RUN=1 — no updates'); quit(); }
const res=db.AppLedgerEntry.updateMany(
  {account:from},
  {\$set:{account:to,internalAccountId:to,mappingIdSnapshot:'SKR03:2026-05-v1:'+to}}
);
printjson(res);
"
REMOTE
  exit $?
fi

mongosh "mongodb://${MONGO_HOST}:27017/${MONGO_DB}" --quiet <<EOF
const from = '${FROM_ACCOUNT}';
const to = '${TO_ACCOUNT}';
const n = db.AppLedgerEntry.countDocuments({ account: from });
print('Rows with account ' + from + ': ' + n);
if (${DRY_RUN} === 1) {
  print('DRY_RUN=1 — no updates. Set DRY_RUN=0 to apply.');
  quit();
}
const res = db.AppLedgerEntry.updateMany(
  { account: from },
  {
    \$set: {
      account: to,
      internalAccountId: to,
      mappingIdSnapshot: '${TO_MAPPING}',
    },
  },
);
printjson(res);
EOF
