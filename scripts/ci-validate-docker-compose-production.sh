#!/usr/bin/env bash
# Validiert docker-compose.production.yml (Syntax + Variableninterpolation) ohne Stack zu starten.
#
# CI: setzt backend/.env aus Stub (nur wenn GITHUB_ACTIONS=true, wie auf GitHub Actions).
# Lokal: entweder bestehendes backend/.env, oder bewusst Stub erzwingen:
#   CI_VALIDATE_COMPOSE_OVERWRITE_BACKEND_ENV=1 ./scripts/ci-validate-docker-compose-production.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

STUB_INTERP="$ROOT/scripts/ci/compose-production-interpolation.env"
STUB_BACKEND="$ROOT/scripts/ci/backend.env.compose-ci-stub"

if [[ ! -f "$STUB_INTERP" ]] || [[ ! -f "$STUB_BACKEND" ]]; then
  echo "ci-validate-docker-compose-production: missing stub env under scripts/ci/" >&2
  exit 1
fi

if [[ "${GITHUB_ACTIONS:-}" == "true" ]] || [[ "${CI_VALIDATE_COMPOSE_OVERWRITE_BACKEND_ENV:-}" == "1" ]]; then
  cp -f "$STUB_BACKEND" "$ROOT/backend/.env"
elif [[ ! -f "$ROOT/backend/.env" ]]; then
  echo "ci-validate-docker-compose-production: backend/.env missing." >&2
  echo "  Create it from backend/env.production.example or run with:" >&2
  echo "  CI_VALIDATE_COMPOSE_OVERWRITE_BACKEND_ENV=1 $0" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "ci-validate-docker-compose-production: docker CLI not found" >&2
  exit 1
fi

docker compose --env-file "$STUB_INTERP" -f docker-compose.production.yml config -q
echo "OK: docker compose production config validates"

GHCR_OVERRIDE="$ROOT/docker-compose.parse-server-ghcr.yml"
if [[ -f "$GHCR_OVERRIDE" ]]; then
  docker compose --env-file "$STUB_INTERP" \
    -f docker-compose.production.yml \
    -f "$GHCR_OVERRIDE" \
    config -q
  echo "OK: production + parse-server GHCR override merge validates"
fi
