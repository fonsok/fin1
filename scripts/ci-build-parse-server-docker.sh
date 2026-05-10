#!/usr/bin/env bash
# Gleicher Parse-Server-Image-Build wie CI (.github/workflows/parse-server-docker-build.yml)
# und wie docker-compose.production.yml (parse-server). Voraussetzung: Docker läuft lokal.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
docker build \
  -f backend/node-service.Dockerfile \
  --build-arg SERVICE_PORT=1337 \
  --build-arg EXTRA_DIR=certs \
  -t fin1-parse-server:ci \
  backend/parse-server
echo "OK: image fin1-parse-server:ci"
