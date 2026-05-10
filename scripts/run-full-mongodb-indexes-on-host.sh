#!/usr/bin/env bash
# Führt backend/mongodb/init/01_indexes.js gegen den lokalen fin1-mongodb-Container aus.
# Voraussetzung: auf dem Ubuntu-Host (iobox), docker compose läuft, Container fin1-mongodb.
# Passwort: MONGO_INITDB_ROOT_PASSWORD aus FIN1_SERVER_DIR/.env (kanonische Quelle).
set -euo pipefail

ROOT="${FIN1_SERVER_DIR:-${HOME}/fin1-server}"
ENV_FILE="${ROOT}/.env"
IDX_FILE="${ROOT}/backend/mongodb/init/01_indexes.js"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "run-full-mongodb-indexes-on-host: missing ${ENV_FILE}" >&2
  exit 1
fi
if [[ ! -f "$IDX_FILE" ]]; then
  echo "run-full-mongodb-indexes-on-host: missing ${IDX_FILE}" >&2
  exit 1
fi

MONGO_PASS="$(python3 - "$ENV_FILE" <<'PY'
import re
import sys
from pathlib import Path

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="replace")
for line in text.splitlines():
    m = re.match(r"^\s*MONGO_INITDB_ROOT_PASSWORD=(.*)$", line)
    if m:
        v = m.group(1).strip()
        if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
            v = v[1:-1]
        print(v, end="")
        raise SystemExit(0)
raise SystemExit("MONGO_INITDB_ROOT_PASSWORD not found")
PY
)"

if [[ -z "$MONGO_PASS" ]]; then
  echo "run-full-mongodb-indexes-on-host: empty password" >&2
  exit 1
fi

echo "run-full-mongodb-indexes-on-host: applying ${IDX_FILE} …"
cat "$IDX_FILE" | docker exec -i fin1-mongodb mongosh --quiet -u admin -p "$MONGO_PASS" --authenticationDatabase admin
echo "run-full-mongodb-indexes-on-host: done"
