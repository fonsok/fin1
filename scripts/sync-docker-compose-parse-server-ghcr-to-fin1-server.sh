#!/usr/bin/env bash
# Kopiert docker-compose.parse-server-ghcr.yml + env-Snippet nach iobox (~/fin1-server/).
# Host: wie deploy-parse-cloud — scripts/.env.server → FIN1_PARSE_CLOUD_SSH_HOST / FIN1_SERVER_USER.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
if [[ -f "$SCRIPT_DIR/.env.server" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/.env.server"
  set +a
fi
REMOTE_USER="${FIN1_SERVER_USER:-io}"
REMOTE_HOST="${FIN1_PARSE_CLOUD_SSH_HOST:-192.168.178.24}"
REMOTE_HOME="~/fin1-server"

echo "=== sync GHCR compose + snippet → ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_HOME} ==="
scp "$ROOT/docker-compose.parse-server-ghcr.yml" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_HOME}/docker-compose.parse-server-ghcr.yml"
scp "$ROOT/scripts/server-home-snippets/env.fin1-parse-ghcr.example" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_HOME}/.env.fin1-parse-ghcr.example"
echo "=== done ==="
