#!/bin/bash
# FIN1 Backup Script (Cron: täglich)
# - Daten: MongoDB, PostgreSQL, Redis
# - Konfiguration: docker-compose.production.yml, backend/.env, nginx.conf
# - TLS & Zertifikate (wenn vorhanden):
#     backend/nginx/ssl/          → Backup: nginx-ssl/
#     backend/parse-server/certs/ → Backup: parse-server-certs/
#     backend/notification-service/certs/ → Backup: notification-service-certs/
# - Optional: fin1-server/.env (Root, falls Compose/Tooling es nutzt)
#
# Manuell: ~/fin1-server/scripts/backup.sh
# Aufbewahrung: RETENTION_DAYS + MIN_BACKUPS_KEEP (siehe unten)

set -euo pipefail

BACKUP_ROOT="${BACKUP_ROOT:-/home/io/fin1-backups}"
FIN1_SERVER="${FIN1_SERVER:-/home/io/fin1-server}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_ROOT}/${DATE}"
RETENTION_DAYS=14
MIN_BACKUPS_KEEP=100
LOG_FILE="${BACKUP_ROOT}/backup.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"; }

# Kopiert Verzeichnisinhalt nach BACKUP_DIR/<dest_name>/ wenn Quelle existiert und nicht leer.
backup_tree_if_nonempty() {
  local src="$1"
  local dest_name="$2"
  if [[ -d "$src" ]] && [[ -n "$(ls -A "$src" 2>/dev/null)" ]]; then
    mkdir -p "${BACKUP_DIR}/${dest_name}"
    cp -a "${src}/." "${BACKUP_DIR}/${dest_name}/"
    local n
    n=$(find "${BACKUP_DIR}/${dest_name}" -type f 2>/dev/null | wc -l | tr -d ' ')
    log "Backed up ${dest_name}/ (${n} file(s)) from ${src}"
  else
    log "SKIP ${dest_name}: missing or empty (${src})"
  fi
}

log "=== Starting FIN1 backup ${DATE} ==="
mkdir -p "${BACKUP_DIR}"

# --- Datenbanken ---
log "Backing up MongoDB..."
if docker exec fin1-mongodb mongodump \
    --archive=/tmp/fin1-mongo-backup.gz \
    --gzip \
    -u admin \
    -p "$(grep MONGO_INITDB_ROOT_PASSWORD "${FIN1_SERVER}/.env" | cut -d= -f2)" \
    --authenticationDatabase admin 2>>"${LOG_FILE}"; then
    docker cp fin1-mongodb:/tmp/fin1-mongo-backup.gz "${BACKUP_DIR}/mongodb.gz"
    docker exec fin1-mongodb rm /tmp/fin1-mongo-backup.gz
    MONGO_SIZE=$(du -h "${BACKUP_DIR}/mongodb.gz" | cut -f1)
    log "MongoDB backup complete: ${MONGO_SIZE}"
else
    log "ERROR: MongoDB backup failed!"
fi

log "Backing up PostgreSQL..."
if docker exec fin1-postgres pg_dump -U fin1_user -d fin1_analytics --no-owner --no-privileges \
    | gzip > "${BACKUP_DIR}/postgresql.sql.gz" 2>>"${LOG_FILE}"; then
    PG_SIZE=$(du -h "${BACKUP_DIR}/postgresql.sql.gz" | cut -f1)
    log "PostgreSQL backup complete: ${PG_SIZE}"
else
    log "ERROR: PostgreSQL backup failed!"
fi

log "Backing up Redis..."
REDIS_PASS=$(grep REDIS_PASSWORD "${FIN1_SERVER}/.env" | cut -d= -f2)
if docker exec fin1-redis redis-cli -a "${REDIS_PASS}" BGSAVE 2>>"${LOG_FILE}"; then
    sleep 2
    docker cp fin1-redis:/data/dump.rdb "${BACKUP_DIR}/redis-dump.rdb" 2>>"${LOG_FILE}"
    RDB_SIZE=$(du -h "${BACKUP_DIR}/redis-dump.rdb" 2>/dev/null | cut -f1)
    log "Redis backup complete: ${RDB_SIZE}"
else
    log "ERROR: Redis backup failed!"
fi

# --- Konfiguration (flache Dateien) ---
log "Backing up configuration files..."
cp "${FIN1_SERVER}/docker-compose.production.yml" "${BACKUP_DIR}/docker-compose.production.yml"
cp "${FIN1_SERVER}/backend/.env" "${BACKUP_DIR}/backend.env"
cp "${FIN1_SERVER}/backend/nginx/nginx.conf" "${BACKUP_DIR}/nginx.conf"

if [[ -f "${FIN1_SERVER}/.env" ]]; then
  cp "${FIN1_SERVER}/.env" "${BACKUP_DIR}/fin1-server-root.env"
  log "Backed up fin1-server root .env as fin1-server-root.env"
else
  log "SKIP fin1-server-root.env: ${FIN1_SERVER}/.env not found"
fi

if [[ -f "${FIN1_SERVER}/docker-compose.production.snap.yml" ]]; then
  cp "${FIN1_SERVER}/docker-compose.production.snap.yml" "${BACKUP_DIR}/docker-compose.production.snap.yml"
  log "Backed up docker-compose.production.snap.yml"
fi

# --- TLS & sonstige Zertifikate (Verzeichnisse) ---
log "Backing up TLS and certificate directories..."
backup_tree_if_nonempty "${FIN1_SERVER}/backend/nginx/ssl" "nginx-ssl"
backup_tree_if_nonempty "${FIN1_SERVER}/backend/parse-server/certs" "parse-server-certs"
backup_tree_if_nonempty "${FIN1_SERVER}/backend/notification-service/certs" "notification-service-certs"

if [[ ! -d "${FIN1_SERVER}/backend/nginx/ssl" ]] || [[ -z "$(ls -A "${FIN1_SERVER}/backend/nginx/ssl" 2>/dev/null)" ]]; then
  log "WARN: nginx/ssl missing or empty — restore/deploy may need manual TLS files"
fi

log "Configuration backup complete"

# --- Kurz-Manifest (lesbar ohne Logs) ---
{
  echo "FIN1 backup ${DATE}"
  echo "FIN1_SERVER=${FIN1_SERVER}"
  ls -la "${BACKUP_DIR}" 2>/dev/null || true
} > "${BACKUP_DIR}/BACKUP_MANIFEST.txt" 2>/dev/null || true

# Cleanup: remove backups older than RETENTION_DAYS, but always keep at least MIN_BACKUPS_KEEP
log "Cleaning backups older than ${RETENTION_DAYS} days (keeping at least ${MIN_BACKUPS_KEEP})..."
TOTAL=$(find "${BACKUP_ROOT}" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
TO_DELETE=$((TOTAL - MIN_BACKUPS_KEEP))
DELETED=0
if [[ $TO_DELETE -gt 0 ]]; then
  while IFS= read -r dir; do
    [[ -z "$dir" || ! -d "$dir" ]] && continue
    if (( DELETED >= TO_DELETE )); then break; fi
    rm -rf "$dir"
    ((DELETED++)) || true
    log "Removed old backup: $(basename "$dir")"
  done < <(find "${BACKUP_ROOT}" -maxdepth 1 -mindepth 1 -type d -mtime +${RETENTION_DAYS} -exec stat -c '%Y %n' {} \; 2>/dev/null | sort -n | cut -d' ' -f2-)
fi
log "Removed ${DELETED} old backup(s), $(find "${BACKUP_ROOT}" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ') retained"

# Summary
TOTAL_SIZE=$(du -sh "${BACKUP_DIR}" | cut -f1)
TOTAL_BACKUPS=$(find "${BACKUP_ROOT}" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
log "=== Backup complete: ${TOTAL_SIZE} total, ${TOTAL_BACKUPS} backup(s) retained ==="
log "Location: ${BACKUP_DIR}"
echo ""
echo "✅ Backup erfolgreich. Ort: ${BACKUP_DIR}"
echo "   Gesamt: ${TOTAL_SIZE} | Behalten: ${TOTAL_BACKUPS} Backup(s)"
