#!/bin/bash
# FIN1 Backup Restore Script
# Usage:
#   ./restore-from-backup.sh                    # list available backups
#   ./restore-from-backup.sh 20260223_124944    # restore this backup (full)
#   ./restore-from-backup.sh 20260223_124944 --config-only  # restore only config files
#
# Run on the server: /home/io/fin1-server/scripts/restore-from-backup.sh

set -euo pipefail

BACKUP_ROOT="${BACKUP_ROOT:-/home/io/fin1-backups}"
FIN1_SERVER="${FIN1_SERVER:-/home/io/fin1-server}"
LOG_FILE="${BACKUP_ROOT}/restore.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"; }

list_backups() {
    echo "Available backup versions (newest first):"
    echo "----------------------------------------"
    for dir in $(find "${BACKUP_ROOT}" -maxdepth 1 -mindepth 1 -type d | sort -r); do
        name=$(basename "$dir")
        if [[ -f "${dir}/mongodb.gz" || -f "${dir}/postgresql.sql.gz" ]]; then
            size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            echo "  $name  ($size)"
        fi
    done
    echo ""
    echo "Restore with: $0 <BACKUP_ID>"
    echo "Example:      $0 20260223_124944"
}

restore_mongodb() {
    local backup_dir="$1"
    local archive="${backup_dir}/mongodb.gz"
    [[ -f "$archive" ]] || { log "MongoDB backup not found: $archive"; return 1; }
    local mongo_pass
    mongo_pass=$(grep MONGO_INITDB_ROOT_PASSWORD "${FIN1_SERVER}/.env" | cut -d= -f2)
    log "Restoring MongoDB from $archive (existing data will be replaced)..."
    docker cp "$archive" fin1-mongodb:/tmp/restore.gz
    docker exec fin1-mongodb mongorestore \
        --archive=/tmp/restore.gz \
        --gzip \
        --drop \
        -u admin \
        -p "${mongo_pass}" \
        --authenticationDatabase admin
    docker exec fin1-mongodb rm /tmp/restore.gz
    log "MongoDB restore complete."
}

restore_postgresql() {
    local backup_dir="$1"
    local dump="${backup_dir}/postgresql.sql.gz"
    [[ -f "$dump" ]] || { log "PostgreSQL backup not found: $dump"; return 1; }
    log "Restoring PostgreSQL (existing fin1_analytics data will be replaced)..."
    docker exec fin1-postgres psql -U fin1_user -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'fin1_analytics' AND pid <> pg_backend_pid();" 2>/dev/null || true
    docker exec fin1-postgres psql -U fin1_user -d postgres -c "DROP DATABASE IF EXISTS fin1_analytics;"
    docker exec fin1-postgres psql -U fin1_user -d postgres -c "CREATE DATABASE fin1_analytics OWNER fin1_user;"
    gunzip -c "$dump" | docker exec -i fin1-postgres psql -U fin1_user -d fin1_analytics
    log "PostgreSQL restore complete."
}

restore_redis() {
    local backup_dir="$1"
    local rdb="${backup_dir}/redis-dump.rdb"
    [[ -f "$rdb" ]] || { log "Redis backup not found: $rdb"; return 1; }
    log "Restoring Redis (container will be restarted, brief cache loss)..."
    docker cp "$rdb" fin1-redis:/data/dump.rdb
    docker restart fin1-redis
    sleep 3
    log "Redis restore complete."
}

restore_config() {
    local backup_dir="$1"
    log "Restoring config files (env, compose, nginx, TLS/certs if present in backup)..."
    [[ -f "${backup_dir}/backend.env" ]] && cp "${backup_dir}/backend.env" "${FIN1_SERVER}/backend/.env" && log "  backend/.env restored"
    [[ -f "${backup_dir}/nginx.conf" ]] && cp "${backup_dir}/nginx.conf" "${FIN1_SERVER}/backend/nginx/nginx.conf" && log "  nginx.conf restored"
    [[ -f "${backup_dir}/docker-compose.production.yml" ]] && cp "${backup_dir}/docker-compose.production.yml" "${FIN1_SERVER}/docker-compose.production.yml" && log "  docker-compose.production.yml restored"
    [[ -f "${backup_dir}/docker-compose.production.snap.yml" ]] && cp "${backup_dir}/docker-compose.production.snap.yml" "${FIN1_SERVER}/docker-compose.production.snap.yml" && log "  docker-compose.production.snap.yml restored"
    [[ -f "${backup_dir}/fin1-server-root.env" ]] && cp "${backup_dir}/fin1-server-root.env" "${FIN1_SERVER}/.env" && log "  fin1-server/.env (root) restored"

    restore_cert_tree() {
        local name="$1"
        local dest="$2"
        if [[ -d "${backup_dir}/${name}" ]] && [[ -n "$(ls -A "${backup_dir}/${name}" 2>/dev/null)" ]]; then
            mkdir -p "${dest}"
            cp -a "${backup_dir}/${name}/." "${dest}/"
            log "  ${dest} restored from backup ${name}/"
        else
            log "  (no ${name}/ in this backup — skip)"
        fi
    }
    restore_cert_tree "nginx-ssl" "${FIN1_SERVER}/backend/nginx/ssl"
    restore_cert_tree "parse-server-certs" "${FIN1_SERVER}/backend/parse-server/certs"
    restore_cert_tree "notification-service-certs" "${FIN1_SERVER}/backend/notification-service/certs"

    log "Config restore complete. If TLS/certs changed: docker compose -f docker-compose.production.yml restart nginx parse-server notification-service"
}

# --- main ---
if [[ "${1:-}" = "" || "${1:-}" = "--list" || "${1:-}" = "-l" ]]; then
    list_backups
    exit 0
fi

BACKUP_ID="$1"
CONFIG_ONLY=false
[[ "${2:-}" = "--config-only" ]] && CONFIG_ONLY=true

BACKUP_DIR="${BACKUP_ROOT}/${BACKUP_ID}"
if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "Error: Backup not found: $BACKUP_DIR"
    list_backups
    exit 1
fi

echo "=============================================="
echo "  FIN1 Restore from backup: $BACKUP_ID"
echo "=============================================="
echo "Location: $BACKUP_DIR"
echo "Contents: $(ls "$BACKUP_DIR" 2>/dev/null | tr '\n' ' ')"
echo ""
if [[ "$CONFIG_ONLY" = true ]]; then
    echo "Mode: Config files only (no databases)."
else
    echo "WARNING: This will REPLACE current MongoDB, PostgreSQL, and Redis data with the backup."
fi
echo ""
if [[ "${RESTORE_CONFIRM:-}" != "yes" ]]; then
    read -p "Type 'yes' to continue: " confirm
    [[ "$confirm" = "yes" ]] || { echo "Aborted."; exit 0; }
else
    echo "RESTORE_CONFIRM=yes set, proceeding."
fi

log "=== Starting restore from $BACKUP_ID ==="

if [[ "$CONFIG_ONLY" = true ]]; then
    restore_config "$BACKUP_DIR"
else
    restore_mongodb "$BACKUP_DIR"
    restore_postgresql "$BACKUP_DIR"
    restore_redis "$BACKUP_DIR"
    if [[ "${RESTORE_CONFIG:-}" = "yes" ]]; then
        restore_config "$BACKUP_DIR"
    else
        read -p "Restore config files as well? [y/N]: " restore_cfg
        [[ "$restore_cfg" = "y" || "$restore_cfg" = "Y" ]] && restore_config "$BACKUP_DIR"
    fi
fi

log "=== Restore finished ==="
echo "Done. If you restored databases, the app may need a moment; check: docker ps"
