#!/usr/bin/env bash
#
# Auf iobox (Ubuntu) ausführen: neuen Parse Master Key setzen.
#
# Voraussetzung: Docker-Stack unter ~/fin1-server, Parse liest PARSE_SERVER_MASTER_KEY aus backend/.env
# (siehe docker-compose.production.yml → env_file: ./backend/.env).
#
# Verwendung:
#   ~/fin1-server/scripts/iobox-rotate-parse-master-key.sh              # interaktiv (Passwort verdeckt)
#   ~/fin1-server/scripts/iobox-rotate-parse-master-key.sh --generate   # zufälligen Key erzeugen
#   ENV_FILE=/pfad/.env ~/fin1-server/scripts/iobox-rotate-parse-master-key.sh --generate
#   ... --no-restart   # nur .env ändern, Container nicht anfassen
#
set -euo pipefail

RESTART_PARSE=1
GENERATE=0
ENV_FILE="${ENV_FILE:-$HOME/fin1-server/backend/.env}"
COMPOSE_DIR="${COMPOSE_DIR:-$HOME/fin1-server}"
COMPOSE_FILE="${COMPOSE_FILE:-$COMPOSE_DIR/docker-compose.production.yml}"

usage() {
  sed -n '1,20p' "$0" | tail -n +2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --generate|-g) GENERATE=1; shift ;;
    --no-restart) RESTART_PARSE=0; shift ;;
    --env-file)
      ENV_FILE="$2"
      shift 2
      ;;
    --compose-dir)
      COMPOSE_DIR="$2"
      COMPOSE_FILE="$COMPOSE_DIR/docker-compose.production.yml"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unbekannte Option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Datei nicht gefunden: $ENV_FILE" >&2
  echo "Tipp: ENV_FILE=/home/io/fin1-server/backend/.env $0" >&2
  exit 1
fi

generate_key() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 40
    echo
  else
    head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 40
    echo
  fi
}

if [[ "$GENERATE" -eq 1 ]]; then
  NEW_KEY="$(generate_key)"
  echo "Neuer Master Key (40 Zeichen, alphanumerisch) wurde erzeugt."
else
  echo "Neuen Parse Master Key eingeben (min. 16 Zeichen, kein Zeilenumbruch, kein '='):"
  read -rs NEW_KEY
  echo
  echo "Wiederholen:"
  read -rs NEW_KEY2
  echo
  if [[ "$NEW_KEY" != "$NEW_KEY2" ]]; then
    echo "Eingaben stimmen nicht überein." >&2
    exit 1
  fi
fi

NEW_KEY="${NEW_KEY//$'\r'/}"
NEW_KEY="${NEW_KEY//$'\n'/}"

if [[ ${#NEW_KEY} -lt 16 ]]; then
  echo "Key zu kurz (min. 16 Zeichen)." >&2
  exit 1
fi
if [[ "$NEW_KEY" == *"="* ]]; then
  echo "Key darf kein '=' enthalten (Konflikt mit .env)." >&2
  exit 1
fi

BACKUP="${ENV_FILE}.backup.masterkey.$(date +%Y%m%d_%H%M%S)"
cp -a "$ENV_FILE" "$BACKUP"
echo "Backup: $BACKUP"

printf '%s' "$NEW_KEY" | python3 -c "
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
key = sys.stdin.read()
if chr(10) in key or chr(13) in key or '=' in key:
    sys.stderr.write('Ungültiger Key (Zeilenumbruch oder =).\n')
    sys.exit(1)

text = path.read_text(encoding='utf-8', errors='replace')
lines = text.splitlines(keepends=True)
out = []
found = False
prefix = 'PARSE_SERVER_MASTER_KEY='
for line in lines:
    if line.startswith(prefix):
        out.append(prefix + key + '\n')
        found = True
    else:
        out.append(line)
if not found:
    if out and not out[-1].endswith('\n'):
        out.append('\n')
    out.append(prefix + key + '\n')

path.write_text(''.join(out), encoding='utf-8')
" "$ENV_FILE"

echo "Aktualisiert: PARSE_SERVER_MASTER_KEY in $ENV_FILE"

if [[ "$GENERATE" -eq 1 ]]; then
  echo ""
  echo "──────── Notieren / Passwortmanager ────────"
  echo "$NEW_KEY"
  echo "────────────────────────────────────────────"
  echo "(Wird nicht erneut angezeigt.)"
fi

if [[ "$RESTART_PARSE" -eq 1 ]]; then
  if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo "Compose-Datei nicht gefunden: $COMPOSE_FILE — Parse nicht neu gestartet." >&2
    echo "Manuell: cd $COMPOSE_DIR && docker compose -f $(basename "$COMPOSE_FILE") up -d parse-server" >&2
    exit 0
  fi
  if ! command -v docker >/dev/null 2>&1; then
    echo "docker nicht im PATH — bitte Parse-Container manuell neu starten." >&2
    exit 0
  fi
  echo "Starte Parse-Container neu (liest .env neu ein) …"
  ( cd "$COMPOSE_DIR" && docker compose -f "$COMPOSE_FILE" up -d parse-server )
  echo "Fertig. Alte Clients/Scripts müssen den neuen Master Key verwenden."
else
  echo "Ohne Neustart: später z. B. cd $COMPOSE_DIR && docker compose -f $(basename "$COMPOSE_FILE") up -d parse-server"
fi
