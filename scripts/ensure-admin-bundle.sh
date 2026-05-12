#!/usr/bin/env bash
# Ensure Docker volume path admin/ contains the built SPA (matches Ubuntu ~/fin1-server/admin/).
# - If admin/index.html is missing, or admin-portal/dist is newer: sync or build (postbuild syncs admin/).
# - Resource-saving: skips work when admin/ is already up to date vs dist/.
#
# Usage: bash scripts/ensure-admin-bundle.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_INDEX="${ROOT}/admin-portal/dist/index.html"
ADMIN_INDEX="${ROOT}/admin/index.html"

needs_sync=false
if [[ ! -f "${ADMIN_INDEX}" ]]; then
  needs_sync=true
elif [[ -f "${DIST_INDEX}" ]] && [[ "${DIST_INDEX}" -nt "${ADMIN_INDEX}" ]]; then
  needs_sync=true
fi

if [[ "${needs_sync}" == false ]]; then
  exit 0
fi

if [[ ! -f "${DIST_INDEX}" ]]; then
  echo "[ensure-admin-bundle] admin-portal/dist fehlt – Production-Build (inkl. Sync nach admin/)…"
  if ! command -v npm >/dev/null 2>&1; then
    echo "[ensure-admin-bundle] npm nicht gefunden. Bitte Node installieren oder manuell:" >&2
    echo "  (cd admin-portal && npm ci && npm run build)" >&2
    exit 1
  fi
  (cd "${ROOT}/admin-portal" && npm run build)
else
  bash "${ROOT}/scripts/sync-admin-portal-to-admin.sh"
fi
