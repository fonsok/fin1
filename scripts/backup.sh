#!/bin/bash
# FIN1 Backup Script (MongoDB, PostgreSQL, Redis, Config)
# - Cron: täglich 3:00 (0 3 * * * .../backup.sh)
# - Manuell: ~/fin1-server/scripts/backup.sh
# Aufbewahrung: Backups älter als RETENTION_DAYS werden gelöscht,
#   es bleiben aber immer mindestens MIN_BACKUPS_KEEP erhalten.

set -euo pipefail

BACKUP_ROOT="${BACKUP_ROOT:-/home/io/fin1-backups}"
FIN1_SERVER="${FIN1_SERVER:-/home/io/fin1-server}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_ROOT}/${DATE}"
RETENTION_DAYS=14
MIN_BACKUPS_KEEP=100
LOG_FILE="${BACKUP_ROOT}/backup.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"; }

log "=== Starting FIN1 backup ${DATE} ==="
mkdir -p "${BACKUP_DIR}"

# MongoDB backup
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

# PostgreSQL backup (pg_dump, NOT pg_dumpall -- safe for restore)
log "Backing up PostgreSQL..."
if docker exec fin1-postgres pg_dump -U fin1_user -d fin1_analytics --no-owner --no-privileges \
    | gzip > "${BACKUP_DIR}/postgresql.sql.gz" 2>>"${LOG_FILE}"; then
    PG_SIZE=$(du -h "${BACKUP_DIR}/postgresql.sql.gz" | cut -f1)
    log "PostgreSQL backup complete: ${PG_SIZE}"
else
    log "ERROR: PostgreSQL backup failed!"
fi

# Redis backup (trigger save and copy RDB)
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

# Config backup
log "Backing up configuration..."
cp "${FIN1_SERVER}/docker-compose.production.yml" "${BACKUP_DIR}/docker-compose.production.yml"
cp "${FIN1_SERVER}/backend/.env" "${BACKUP_DIR}/backend.env"
cp "${FIN1_SERVER}/backend/nginx/nginx.conf" "${BACKUP_DIR}/nginx.conf"
log "Configuration backup complete"

# Cleanup: remove backups older than RETENTION_DAYS, but always keep at least MIN_BACKUPS_KEEP
log "Cleaning backups older than ${RETENTION_DAYS} days (keeping at least ${MIN_BACKUPS_KEEP})..."
TOTAL=$(find "${BACKUP_ROOT}" -maxdepth 1 -mindepth 1 -type d | wc -l)
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
log "Removed ${DELETED} old backup(s), $(find "${BACKUP_ROOT}" -maxdepth 1 -mindepth 1 -type d | wc -l) retained"

# Summary
TOTAL_SIZE=$(du -sh "${BACKUP_DIR}" | cut -f1)
TOTAL_BACKUPS=$(find "${BACKUP_ROOT}" -maxdepth 1 -mindepth 1 -type d | wc -l)
log "=== Backup complete: ${TOTAL_SIZE} total, ${TOTAL_BACKUPS} backup(s) retained ==="
log "Location: ${BACKUP_DIR}"
echo ""
echo "✅ Backup erfolgreich. Ort: ${BACKUP_DIR}"
echo "   Gesamt: ${TOTAL_SIZE} | Behalten: ${TOTAL_BACKUPS} Backup(s)"
