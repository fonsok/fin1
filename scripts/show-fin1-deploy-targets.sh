#!/usr/bin/env bash
# Print effective FIN1 server deploy targets (reads scripts/.env.server if present).
# Canonical doc: Documentation/OPERATIONAL_DEPLOY_HOSTS.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
if [[ -f "$SCRIPT_DIR/.env.server" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/.env.server"
  set +a
fi

USER="${FIN1_SERVER_USER:-io}"
CANONICAL_HTTPS_IP="192.168.178.24"
ADMIN_HOST="${FIN1_SERVER_IP:-$CANONICAL_HTTPS_IP}"
CLOUD_HOST="${FIN1_PARSE_CLOUD_SSH_HOST:-$CANONICAL_HTTPS_IP}"

echo "=== FIN1 deploy targets (iobox) ==="
echo ""
echo "  Canonical HTTPS / Parse in docs & clients: https://${CANONICAL_HTTPS_IP}/parse"
echo "  Same host, Ethernet (typ.):                 ${USER}@192.168.178.20"
echo ""
echo "  Effective SSH/rsync:"
echo "    Admin portal (FIN1_SERVER_IP):  ${USER}@${ADMIN_HOST}  → ~/fin1-server/admin/"
echo "    Parse cloud   (FIN1_PARSE_CLOUD_SSH_HOST or default .24): ${USER}@${CLOUD_HOST}  → ~/fin1-server/backend/parse-server/cloud/"
echo "    GHCR compose  (same SSH as Parse cloud):  ./scripts/sync-docker-compose-parse-server-ghcr-to-fin1-server.sh"
echo "        → ~/fin1-server/docker-compose.parse-server-ghcr.yml + .env.fin1-parse-ghcr.example"
echo ""

if [[ "$ADMIN_HOST" != "$CLOUD_HOST" ]]; then
  echo "  Note: Admin and Parse cloud use different SSH targets — same machine if both"
  echo "        IPs are bound to iobox (see Documentation/OPERATIONAL_DEPLOY_HOSTS.md)."
  echo ""
fi

if [[ ! -f "$SCRIPT_DIR/.env.server" ]]; then
  echo "  (No scripts/.env.server — defaults above. Copy scripts/.env.server.example.)"
  echo ""
fi
