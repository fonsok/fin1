#!/usr/bin/env bash
# Deploy Parse Cloud Code to iobox: shadow check, rsync cloud/, remove configHelper.js shadow, restart parse-server.
# Host: FIN1_PARSE_CLOUD_SSH_HOST or 192.168.178.24 (see Documentation/OPERATIONAL_DEPLOY_HOSTS.md).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
if [[ -f "$SCRIPT_DIR/.env.server" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/.env.server"
  set +a
fi

REMOTE_USER="${FIN1_SERVER_USER:-io}"
CANONICAL_DEFAULT_CLOUD_HOST="192.168.178.24"
REMOTE_HOST="${FIN1_PARSE_CLOUD_SSH_HOST:-$CANONICAL_DEFAULT_CLOUD_HOST}"
REMOTE_CLOUD="~/fin1-server/backend/parse-server/cloud/"
# Schrittweiser Deploy-Ausbau: Manifest (Git-SHA + Cloud-Tree-Hash) auf den Server schreiben (0=aus).
WRITE_DEPLOY_MANIFEST="${WRITE_DEPLOY_MANIFEST:-1}"

echo "=== Parse Cloud deploy → ${REMOTE_USER}@${REMOTE_HOST} ==="
echo ""

"$SCRIPT_DIR/check-parse-cloud-config-helper-shadow.sh"

echo "▸ rsync cloud/ (exclude Jest tests: __tests__, *.test.js) …"
rsync -avz \
  --exclude='__tests__' \
  --exclude='*.test.js' \
  "$PROJECT_ROOT/backend/parse-server/cloud/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_CLOUD}"

echo "▸ remove configHelper.js shadow (if any) + restart parse-server …"
ssh "${REMOTE_USER}@${REMOTE_HOST}" "rm -f ~/fin1-server/backend/parse-server/cloud/utils/configHelper.js && cd ~/fin1-server && docker compose -f docker-compose.production.yml restart parse-server"

if [[ "${WRITE_DEPLOY_MANIFEST}" != "0" ]]; then
  echo "▸ deploy manifest (~/fin1-server/deploy-manifests/) …"
  MANIFEST_JSON="$("$SCRIPT_DIR/write-deploy-manifest.sh" --component parse-cloud)"
  # shellcheck disable=SC2029
  ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ~/fin1-server/deploy-manifests && cat > ~/fin1-server/deploy-manifests/parse-cloud-latest.json" <<<"$MANIFEST_JSON"
  # shellcheck disable=SC2029
  ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ~/fin1-server/deploy-manifests && cat >> ~/fin1-server/deploy-manifests/history.log" <<<"$(printf '%s %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$(echo "$MANIFEST_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["gitCommit"])')")"
fi

echo ""
echo "=== Parse Cloud deploy done ==="
