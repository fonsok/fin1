#!/bin/bash
# FIN1 – Basis-Services (Redis, MongoDB, Postgres, Minio, Uptime-Kuma) starten
# Nutzen: Nach Reboot oder wenn diese Container "Exit 0" sind.
# Aufruf auf dem Server: cd ~/fin1-server && bash scripts/start-fin1-base-services.sh

set -e
cd "$(dirname "$0")/.."
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.production.yml}"

echo "Starting base services: redis, mongodb, postgres, minio, uptime-kuma..."
docker-compose -f "$COMPOSE_FILE" up -d redis mongodb postgres minio uptime-kuma

echo "Waiting for health checks (30s)..."
sleep 30

echo "Status:"
docker-compose -f "$COMPOSE_FILE" ps redis mongodb postgres minio uptime-kuma

echo "Done. Start app stack with: docker-compose -f $COMPOSE_FILE up -d"
