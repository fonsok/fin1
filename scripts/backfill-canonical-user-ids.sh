#!/usr/bin/env bash
# One-time migration: legacy `user:email` person keys → Parse `_User.objectId`.
#
# Usage:
#   ./scripts/backfill-canonical-user-ids.sh
#   APPLY=1 ./scripts/backfill-canonical-user-ids.sh
#
# Server (from repo on iobox):
#   APPLY=1 FIN1_SERVER_USER=io FIN1_PARSE_CLOUD_SSH_HOST=192.168.178.20 \
#     ./scripts/backfill-canonical-user-ids.sh --remote

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REMOTE=0
if [[ "${1:-}" == "--remote" ]]; then
  REMOTE=1
fi

if [[ "$REMOTE" == "1" ]]; then
  # shellcheck disable=SC1091
  [[ -f "$ROOT/scripts/.env.server" ]] && source "$ROOT/scripts/.env.server"
  HOST="${FIN1_PARSE_CLOUD_SSH_HOST:-192.168.178.20}"
  USER="${FIN1_SERVER_USER:-io}"
  echo "▸ Remote backfill on ${USER}@${HOST} (APPLY=${APPLY:-0})"
  scp "$ROOT/backend/scripts/backfill-canonical-user-ids.js" "${USER}@${HOST}:~/fin1-server/backend/scripts/"
  ssh "${USER}@${HOST}" bash -s <<EOF
set -euo pipefail
MONGO_PASS=\$(docker exec fin1-mongodb printenv MONGO_INITDB_ROOT_PASSWORD)
APPLY=${APPLY:-0}
docker cp ~/fin1-server/backend/scripts/backfill-canonical-user-ids.js fin1-parse-server:/app/backfill-canonical-user-ids.js
docker exec -w /app -e APPLY="\$APPLY" -e MONGO_URL="mongodb://admin:\${MONGO_PASS}@mongodb:27017/fin1?authSource=admin" \
  fin1-parse-server node /app/backfill-canonical-user-ids.js
EOF
  exit 0
fi

echo "Mode: ${APPLY:-DRY-RUN (set APPLY=1 to write)}"
node backend/scripts/backfill-canonical-user-ids.js
