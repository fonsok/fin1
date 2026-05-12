# Deployment: rsync und Server-Spiegelung (Sicherheitshinweis)

**Zielgruppe:** Betrieb, Backend-Entwicklung  
**Bezug:** [`scripts/deploy-to-ubuntu.sh`](../scripts/deploy-to-ubuntu.sh), [`backend/README.md`](../backend/README.md)

## Problem

Auf dem Produktions-Server liegt unter `~/fin1-server/backend/` (o. ä.) oft **mehr** als im Git-Repository:

- TLS-Material (`nginx/ssl/`, ggf. weitere Zertifikate)
- `parse-server/certs/`, Log-Verzeichnisse
- Dateien für Services, die im Repo nur teilweise abgebildet sind (z. B. `package.json` / Code nur auf dem Server für Image-Builds)
- lokale Anpassungen und Backups

## Regel

**`rsync --delete` nicht** auf diesen Backend-Baum anwenden, solange der Server **kein** garantiert identischer Klon des Repos ist.

`--delete` entfernt auf dem Ziel alles, was in der Quelle fehlt — das kann **Zertifikate, Logs und produktionskritische Dateien** löschen.

## Empfohlene Vorgehensweise

- Deployment mit dem Projekt-Skript **`scripts/deploy-to-ubuntu.sh`**: Es synchronisiert **ohne** `--delete` und schließt übliche Artefakte aus (`node_modules`, `.env`, …).
- Manuelles `rsync`: dieselben Excludes, **ohne** `--delete**, sofern nicht explizit eine Spiegelung gewollt ist.
- Nach Änderungen an **Cloud Code** den **Parse-Container** neu starten bzw. euren dokumentierten Compose-Workflow nutzen, damit der Server die neuen Funktionen lädt.

## Nginx / Smoke-Check (häufige Ursachen)

1. **Docker-Netzwerk drift**: Wenn einzelne Container (z. B. nur `nginx`) neu erstellt wurden, können sie auf einem anderen Compose-Netzwerk hängen als `parse-server` oder `market-data` → `502`, „Host is unreachable“, oder Nginx startet nicht (`host not found in upstream`). **Abhilfe:** im Server-Verzeichnis `cd ~/fin1-server && docker compose -f docker-compose.production.yml up -d` (stellt die in der Compose-Datei definierten Netzwerke wieder her).
2. **TLS-Dateien fehlen** (`backend/nginx/ssl/fullchain.pem`, `privkey.pem`): Nginx kann HTTPS nicht laden. **Abhilfe:** Zertifikate aus Backup wiederherstellen oder temporär selbstsigniert erzeugen, bis die produktiven Zertifikate zurückliegen.
3. **Smoke-Check** (`scripts/fin1-smoke-check.sh`): Liegen `docker-compose.yml` und `docker-compose.production.yml` nebeneinander, nutzt das Skript standardmäßig zuerst `docker-compose.yml`. Für den **Produktions-Stack** auf dem Server setzen:  
   `export FIN1_SMOKE_COMPOSE_FILE="$HOME/fin1-server/docker-compose.production.yml"`

## Tägliche Backups unter `/home/io/fin1-backups/`

- Enthalten **Datenbanken** und **Config** (`scripts/backup.sh`).
- **Zertifikate / TLS** (wenn die Verzeichnisse auf dem Server nicht leer sind), jeweils als Unterordner im Backup:
  - **`nginx-ssl/`** ← `backend/nginx/ssl/`
  - **`parse-server-certs/`** ← `backend/parse-server/certs/`
  - **`notification-service-certs/`** ← `backend/notification-service/certs/`
  - optional **`fin1-server-root.env`** (Kopie von `~/fin1-server/.env`, falls vorhanden)
- **Ältere** Snapshots vor dieser Logik haben diese Ordner **nicht** — gelöschte Zertifikate sind daraus **nicht** rekonstruierbar.
- **Nach Wiederherstellung:** `restore-from-backup.sh … --config-only` spiegelt die gleichen Pfade zurück; ggf. **`docker compose … restart nginx`** (und bei Bedarf Parse/Notification).

## Verwandte Doku

- Englisch (technisch): Abschnitt **Deployment safety** in [`backend/README.md`](../backend/README.md)
- Betrieb Ubuntu / iobox: [`Documentation/FIN1_APP_DOCS/06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md`](FIN1_APP_DOCS/06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md)
- Welcher Deploy wohin (zwei LAN-IPs, `scripts/.env.server`): [`OPERATIONAL_DEPLOY_HOSTS.md`](OPERATIONAL_DEPLOY_HOSTS.md)
