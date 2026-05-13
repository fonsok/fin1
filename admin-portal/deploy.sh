#!/usr/bin/env bash
# FIN1 Admin Portal: production build + rsync to ~/fin1-server/admin/
# SSH/rsync host: FIN1_SERVER_IP from scripts/.env.server (default 192.168.178.24).
# See Documentation/OPERATIONAL_DEPLOY_HOSTS.md and ./scripts/show-fin1-deploy-targets.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck source=../scripts/.env.server
[ -f "$SCRIPT_DIR/../scripts/.env.server" ] && source "$SCRIPT_DIR/../scripts/.env.server"

REMOTE_USER="${FIN1_SERVER_USER:-io}"
REMOTE_HOST="${FIN1_SERVER_IP:-192.168.178.24}"
REMOTE_DIR="~/fin1-server/admin/"
LOCAL_DIST="dist/"

echo "=== FIN1 Admin Portal – Build & Deploy ==="
echo ""

# ── 1. Clean build ──────────────────────────────────────────
echo "▸ Step 1/4: Building (dist/ will be cleaned automatically)…"
npm run build
echo "  ✔ Build complete"
echo ""

# ── 2. Capture the JS bundle name from index.html ──────────
# (sed used for portability: macOS grep has no -P)
LOCAL_JS=$(sed -n 's/.*src="\/admin\/assets\/\([^"]*\)".*/\1/p' dist/index.html | head -1)
if [[ -z "$LOCAL_JS" ]]; then
  echo "  ✘ ERROR: Could not find JS bundle reference in dist/index.html"
  exit 1
fi
echo "  Local JS bundle: $LOCAL_JS"
echo ""

# ── 3. Deploy via rsync ────────────────────────────────────
echo "▸ Step 2/4: Deploying to ${REMOTE_HOST}…"
rsync -avz --delete "$LOCAL_DIST" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"
echo "  ✔ rsync complete"
echo ""

# ── 4. Verify remote matches local ─────────────────────────
echo "▸ Step 3/4: Verifying remote deployment…"
REMOTE_JS=$(ssh "${REMOTE_USER}@${REMOTE_HOST}" "sed -n 's/.*src=\"\\/admin\\/assets\\/\\([^\"]*\\)\".*/\1/p' ${REMOTE_DIR}index.html | head -1")
REMOTE_EXISTS=$(ssh "${REMOTE_USER}@${REMOTE_HOST}" "test -f ${REMOTE_DIR}assets/${LOCAL_JS} && echo yes || echo no")

if [[ "$REMOTE_JS" != "$LOCAL_JS" ]]; then
  echo "  ✘ MISMATCH: Remote index.html references '$REMOTE_JS' but expected '$LOCAL_JS'"
  exit 1
fi

if [[ "$REMOTE_EXISTS" != "yes" ]]; then
  echo "  ✘ MISSING: JS bundle '${LOCAL_JS}' not found on remote server"
  exit 1
fi

echo "  ✔ Remote index.html → $REMOTE_JS (matches local)"
echo "  ✔ JS bundle exists on server"
echo ""

# ── 5. Nginx neu erstellen (Bind-Mount /var/www/admin ↔ ~/fin1-server/admin) ──
# Ohne Recreate kann ein alter fin1-nginx-Container noch alte index-*.js ausliefern,
# obwohl rsync auf dem Host bereits neue Dateien hat (Nutzer sieht fehlende Sidebar-Einträge).
echo "▸ Step 3b/4: Recreating nginx container (refresh admin bind mount)…"
ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd ~/fin1-server && docker compose -f docker-compose.production.yml up -d --force-recreate --no-deps nginx"
echo "  ✔ nginx recreated"
echo ""

# ── 6. Summary ──────────────────────────────────────────────
echo "▸ Step 4/4: Summary"
echo "  Local assets:"
ls -lh dist/assets/
echo ""
echo "  Remote assets:"
ssh "${REMOTE_USER}@${REMOTE_HOST}" "ls -lh ${REMOTE_DIR}assets/"
echo ""
echo "=== Deploy successful ✔ ==="
