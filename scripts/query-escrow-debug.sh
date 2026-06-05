#!/usr/bin/env bash
# Debug escrow legs for investment IDs (server mongosh).
set -euo pipefail
IDS="${1:-tWTDeXQya6}"
ssh io@192.168.178.20 bash -s "$IDS" <<'REMOTE'
IDS="$1"
cd ~/fin1-server
MONGO_PASSWORD=$(grep -E '^MONGO_INITDB_ROOT_PASSWORD=' .env | tail -1 | cut -d= -f2- | tr -d '"' | tr -d "'")
docker compose -f docker-compose.production.yml exec -T mongodb mongosh --quiet \
  --username admin --password "$MONGO_PASSWORD" --authenticationDatabase admin fin1 \
  --eval "const ids='$IDS'.split(','); ids.forEach(id=>{print('\\n==== '+id); const inv=db.Investment.findOne({_id:id}); if(inv) print('num='+inv.investmentNumber+' st='+inv.status+' amt='+inv.amount); db.AppLedgerEntry.find({referenceId:id,transactionType:'investmentEscrow'}).forEach(r=>{const leg=(r.metadata&&r.metadata.leg)||'?'; print(r.account+' '+r.side+' '+r.amount+' leg='+leg);});});"
REMOTE
