#!/usr/bin/env bash
# Set or update BA_PASSWORD in scripts/.env.server (gitignored, Mac only).
# Used by smoke-admin-get-user-details.sh and create-*-admin.sh.
# See Documentation/DEV_PORTAL_LOGIN_SSOT.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env.server"
EXAMPLE="${SCRIPT_DIR}/.env.server.example"

if [[ ! -f "${ENV_FILE}" ]]; then
  if [[ ! -f "${EXAMPLE}" ]]; then
    echo "FAIL: ${EXAMPLE} fehlt — Repo unvollständig." >&2
    exit 1
  fi
  cp "${EXAMPLE}" "${ENV_FILE}"
  echo "Angelegt: ${ENV_FILE} (aus .env.server.example)"
fi

read -r -s -p "Neues BA_PASSWORD (Portal-Admin): " pw1
echo
read -r -s -p "BA_PASSWORD wiederholen: " pw2
echo

if [[ -z "${pw1}" ]]; then
  echo "FAIL: Passwort darf nicht leer sein." >&2
  exit 1
fi
if [[ "${pw1}" != "${pw2}" ]]; then
  echo "FAIL: Passwörter stimmen nicht überein." >&2
  exit 1
fi

BA_PASSWORD_NEW="${pw1}" python3 - "${ENV_FILE}" <<'PY'
import os
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
password = os.environ["BA_PASSWORD_NEW"]

def shell_single_quoted(value: str) -> str:
    return "'" + value.replace("'", "'\"'\"'") + "'"

lines = path.read_text(encoding="utf-8").splitlines()
out = []
replaced = False
pattern = re.compile(r"^\s*#?\s*BA_PASSWORD=")

for line in lines:
    if pattern.match(line):
        out.append(f"BA_PASSWORD={shell_single_quoted(password)}")
        replaced = True
    else:
        out.append(line)

if not replaced:
    if out and out[-1].strip():
        out.append("")
    out.append(f"BA_PASSWORD={shell_single_quoted(password)}")

path.write_text("\n".join(out) + "\n", encoding="utf-8")
PY

echo "OK: BA_PASSWORD in ${ENV_FILE} gespeichert (gitignored)."
echo "Test: ./scripts/smoke-admin-get-user-details.sh"
