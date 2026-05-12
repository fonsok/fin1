#!/usr/bin/env bash
# Sync built Admin Portal into repo admin/, matching Ubuntu fin1-server layout:
#   ~/fin1-server/admin/  ←  contents of admin-portal/dist/
# Docker mounts: ./admin:/var/www/admin
#
# Policy A (repo): admin/ build output is listed in .gitignore — never commit the
# synced files. CI runs `npm run build` in admin-portal only to verify the build;
# the postbuild hook may populate admin/ on the runner, but that tree is discarded
# with the job. Production deploy: admin-portal/deploy.sh (rsync dist/ to server).
#
# Usage (from repo root):
#   bash scripts/sync-admin-portal-to-admin.sh
# Or after build only:
#   (cd admin-portal && npm run build) && bash scripts/sync-admin-portal-to-admin.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="${ROOT}/admin-portal/dist"
TARGET="${ROOT}/admin"

if [[ ! -f "${DIST}/index.html" ]]; then
  echo "Missing ${DIST}/index.html — run first: (cd admin-portal && npm run build)" >&2
  exit 1
fi

mkdir -p "${TARGET}"
rsync -a --delete "${DIST}/" "${TARGET}/"
echo "Synced admin-portal/dist/ → admin/ (same as scp dist/* ~/fin1-server/admin/)"
