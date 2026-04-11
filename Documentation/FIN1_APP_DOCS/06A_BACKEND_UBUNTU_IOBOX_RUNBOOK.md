---
title: "FIN1 Backend – Ubuntu Runbook (iobox, User io)"
audience: ["Betrieb", "Backend-Entwicklung", "Security", "Release Management"]
lastUpdated: "2026-03-28"
---

## Zweck

Dieses Runbook dokumentiert den **realen** Backend-Betrieb auf dem Ubuntu-Server **`iobox`** (User `io`). Inhalte sind aus Live-Checks auf dem Server abgeleitet.

## 1) Server-Identität & Zugriff

- **Host**: `iobox`
- **OS**: Ubuntu 24.04.3 LTS (Kernel `6.8.0-90-generic`)
- **LAN-IP (Projektstandard)**: `192.168.178.24` (siehe bestehende Netzwerk-Dokumente)
- **SSH User**: `io`

### SSH (Operator)

- **Direkt (LAN)**: `ssh io@192.168.178.24`
- **Host Alias**: `ssh io@iobox` (wenn Nameauflösung im LAN aktiv ist)

## 2) Deployment-Verzeichnis & Struktur

**Hinweis (rsync):** Backend-Deployments **nicht** mit `rsync --delete` gegen den Server spiegeln, wenn dort Dateien liegen, die **nicht** im Repo sind (Zertifikate, lokale Service-Dateien, …). Kurzbeschreibung: [`Documentation/DEPLOYMENT_RSYNC_SICHERHEIT.md`](../DEPLOYMENT_RSYNC_SICHERHEIT.md).

**Base Directory (Production/Server):**

- `/home/io/fin1-server`

**Wichtige Unterordner/Dateien:**

- `backend/` – Service-Quellen/Configs (Parse Server, Nginx, Services, `.env`)
- `logs/` – Host-seitige Log-Verzeichnisse für Container/Tools
- `docker-compose.production.yml` – Produktions-Compose (aktiver Stack)
- `docker-compose.yml` / `docker-compose.simple.yml` – alternative Setups
- `auto-start-services.sh` – Service Monitor (Auto-Restart via Compose)
- `scripts/backup.sh` – automatisches Backup (Cron 3:00); `scripts/restore-from-backup.sh` – Restore (siehe `scripts/BACKUP_RESTORE.md`)
- `service-monitor.service` – Systemd Unit (liegt im Repo-Ordner, ist **nicht** installiert)

## 3) Aktiver Stack (docker compose – Produktion)

### Versionen

- Docker: `28.2.2`
- Docker Compose: `v5.0.1`

### Running Containers (Ist-Zustand)

Aus `docker compose -f docker-compose.production.yml ps`:

- **`fin1-nginx`**: `:80`, `:443` (öffentlich)
- **`fin1-parse-server`**: `127.0.0.1:1338 -> 1337` (**nur localhost**)
- **`fin1-mongodb`**: `127.0.0.1:27018 -> 27017` (**nur localhost**, nach Hardening)
- **`fin1-redis`**: `127.0.0.1:6380 -> 6379` (**nur localhost**)
- **`fin1-postgres`**: `127.0.0.1:5433 -> 5432` (**nur localhost**)
- **`fin1-minio`**: `127.0.0.1:9002/9003` (**nur localhost**, nach Hardening)
- **`fin1-market-data`**: `127.0.0.1:8083` (**nur localhost**)
- **`fin1-notification-service`**: `127.0.0.1:8084` (**nur localhost**)
- **`fin1-analytics-service`**: `127.0.0.1:8085` (**nur localhost**)
- **`fin1-uptime-kuma`** (Monitoring): `127.0.0.1:3001` (optional per UFW freigegeben)

**Wichtig**

- Nach Hardening (Feb 2026): Parse Server und alle DBs/Service-Ports nur auf **127.0.0.1**. Zugriff von LAN ausschließlich über Nginx (HTTPS :443). Siehe `Documentation/SERVER_HARDENING_2026-02.md`.

### 3.1 Source of Truth: Port-Bindings aus `docker-compose.production.yml` (Server)

Quelle: `/home/io/fin1-server/docker-compose.production.yml` (Ports-Blocks).

- **parse-server**
  - `"127.0.0.1:1338:1337"` (nur localhost)
- **mongodb**
  - `"127.0.0.1:27018:27017"` (nur localhost)
- **redis**
  - `"127.0.0.1:6380:6379"` (nur localhost)
- **postgres**
  - `"127.0.0.1:5433:5432"` (nur localhost)
- **minio**
  - `"127.0.0.1:9002:9000"` (nur localhost)
  - `"127.0.0.1:9003:9001"` (nur localhost)
- **nginx**
  - `"80:80"` (Redirect auf HTTPS), `"443:443"` (HTTPS, öffentlich)
- **market-data** / **notification-service** / **analytics-service**
  - `"127.0.0.1:8083:8080"` usw. (nur localhost)

### 3.2 Zusätzliche offene OS-Ports (nicht aus Compose dokumentiert)

Aus `ss -ltn` (Server):

- **Samba (SMB)**: Ports `139` und `445` sind offen.
  - Services: `smbd` und `nmbd` sind **enabled + active**.
- **Remote Desktop (RDP)**: Port `3389` ist offen.
  - Prozess: `gnome-remote-desktop` (läuft als User `io`).
- **Port 8000**: offen auf `0.0.0.0:8000`, Prozessname ohne sudo nicht sichtbar.
  - Hinweis: `sudo` ist für User `io` **nicht** passwordless (`sudo -n` schlägt fehl). Für Ursachenanalyse auf dem Server mit interaktivem sudo:
    - `sudo ss -ltnp | grep :8000`
    - `sudo lsof -nP -iTCP:8000 -sTCP:LISTEN`

## 4) Externe Endpoints (über Nginx)

Nginx Konfiguration: `/home/io/fin1-server/backend/nginx/nginx.conf`

Aktive Routen:

- **Parse API**: `https://<host>/parse` (Proxy auf Parse Server)
- **LiveQuery WS**: `wss://<host>/parse` (Upgrade/WS Header werden gesetzt)
- **Health**: `https://<host>/health` (Proxy auf Parse `/health`)
- **API Docs**: `https://<host>/api-docs` (nur von localhost, Nginx `allow 127.0.0.1; deny all`)

Service-Routes (Reverse Proxy):

- **Market Data**: `https://<host>/api/market-data/` → `fin1-market-data`
- **Notifications**: `https://<host>/api/notifications/` → `fin1-notification-service`
- **Analytics**: `https://<host>/api/analytics/` → `fin1-analytics-service`

Absichtlich eingeschränkt:

- **Parse Dashboard**: `/dashboard/` nur von **localhost** (Nginx `allow 127.0.0.1; deny all` → von LAN 403).

## 5) Parse Dashboard (sicherer Zugriff)

Parse Dashboard ist nur über **SSH Tunnel** sinnvoll, weil es den `serverURL` in die Browser-App embeded.

### Empfohlenes Setup

- Dashboard wird über Nginx unter `/dashboard/` ausgeliefert; Nginx hört auf 443 (HTTPS).
- Tunnel (Mac → Server):

```bash
ssh -L 443:127.0.0.1:443 io@192.168.178.24
```

- Dashboard im Browser (Mac): `https://localhost/dashboard/` (bei self-signed Zertifikat Warnung bestätigen)

Relevante `.env` Variable:

- `PARSE_DASHBOARD_SERVER_URL` (z. B. `http://localhost:1338/parse` für Dashboard-Frontend)

## 6) Konfiguration (Secrets, URLs, Legal Identity)

### Backend Environment File

- **Pfad**: `/home/io/fin1-server/backend/.env`
- Enthält u.a.:
  - Parse (`PARSE_SERVER_*`, `PARSE_DASHBOARD_*`)
  - DB Credentials (`MONGO_*`, `POSTGRES_*`, `REDIS_*`)
  - MinIO/S3 (`MINIO_*`, `S3_*`)
  - Security (`JWT_SECRET`, `ENCRYPTION_KEY`)
  - Legal Placeholder Values (`FIN1_LEGAL_*`)
  - CORS (`ALLOWED_ORIGINS`)
  - Server Identität (`SERVER_IP`, `SERVER_HOSTNAME`)
  - Zusätzlich (Notification Service): `SUPABASE_*` Variablen sind vorhanden (ohne Werte in Doku).

**Regel**

- Werte niemals in Git/Docs committen.
- Änderungen an `FIN1_LEGAL_*` sind auditkritisch: Legal Content muss versioniert/append-only bleiben.

### Wichtig: `.env` ist nicht “source”-bar

Die Datei `backend/.env` ist **nicht garantiert shell-kompatibel** (kann Leerzeichen, Klammern oder `+49 (0) ...` enthalten). Deshalb:

- **Nicht** `source backend/.env` oder `. backend/.env` verwenden.
- Wenn du einzelne Werte brauchst (z.B. `MONGO_INITDB_ROOT_PASSWORD`), extrahiere sie gezielt (z.B. via `python3`/grep) oder nutze `docker compose config`/Container‑Env.

### Wichtig: ENV Änderungen in `env_file` → Container neu erstellen

`docker compose restart parse-server` lädt `env_file` nicht immer zuverlässig neu.

Best practice nach `.env` Änderungen:

```bash
cd /home/io/fin1-server
docker compose -f docker-compose.production.yml up -d --force-recreate --no-deps parse-server
```

## 7) Standard-Operator-Kommandos (nicht destruktiv)

Im Server-Verzeichnis `/home/io/fin1-server`:

- Status:
  - `docker compose -f docker-compose.production.yml ps`
- Logs (Beispiele):
  - `docker compose -f docker-compose.production.yml logs --tail=200 parse-server`
  - `docker compose -f docker-compose.production.yml logs --tail=200 nginx`
- Health:
  - `curl -sk https://localhost/health` (über Nginx, lokal auf Server; `-k` bei self-signed)
  - `curl -sk https://192.168.178.24/health` (von außen, LAN)

## 8) Deployment/Update Ablauf (bewährter Flow)

Typischer Update (Beispiel Parse Server):

1. **Code/Config auf Server aktualisieren** (z.B. per `scp` nach `/home/io/fin1-server/...`)
2. **Build**:
   - `cd /home/io/fin1-server`
   - `docker compose -f docker-compose.production.yml build parse-server`
3. **Rollout**:
   - `docker compose -f docker-compose.production.yml up -d --force-recreate parse-server`
4. **Verify**
  - `docker compose -f docker-compose.production.yml ps`
  - `curl -sk https://localhost/health`
  - extern: `curl -sk https://192.168.178.24/health` und `curl -sk https://192.168.178.24/parse/health`

### 8.2) Refactor-Deploy Checkliste (Cloud Code, 2026-03 Ergänzung)

Für interne Refactorings ohne API-Verhaltensänderung (Loader + Submodule) hat sich folgender schnelle Verify-Flow bewährt:

1. Zielordner auf Server sicherstellen (z. B. `cloud/utils/<modul>/`, `cloud/functions/admin/<modul>/`).
2. Geänderte Dateien per `scp` in `/home/io/fin1-server/backend/parse-server/cloud/...` übertragen.
3. Parse-Service neu laden:
   - `docker compose up -d parse-server`
4. Gesundheitszustand prüfen:
   - `docker compose ps parse-server nginx mongodb redis`
   - `curl -sS http://127.0.0.1:1338/health`
5. Auth-Grenze prüfen (ohne Token):
   - Beispiel `getPendingApprovals` sollte erwartbar `Login required` liefern.
6. Authentifizierten Smoke-Check mit gültigem Session-Token ausführen:
   - gleiche Funktion sollte reguläre `result`-Payload zurückgeben.

Diese Sequenz wurde am 2026-03-19 für folgende Refactors erfolgreich durchgeführt:

- `cloud/utils/permissions.js` + `cloud/utils/permissions/*`
- `cloud/utils/accountingHelper.js` + `cloud/utils/accountingHelper/*`
- `cloud/functions/admin/fourEyes.js` + `cloud/functions/admin/fourEyes/*`

**Neue Cloud Functions & Admin-Portal („Invalid function“):** Wird im Browser (z. B. Admin **Hilfe & Anleitung**) nach Copy der Dateien auf den Host weiterhin **`Invalid function`** für einen **neuen** Function-Namen gemeldet, nutzt der Container vermutlich **kein** Live-Volume auf `backend/parse-server/cloud` (Cloud Code nur im **Image**). Dann reicht `scp`/`rsync` nach `/home/io/fin1-server/backend/parse-server/cloud/` allein nicht: **Compose anpassen** (analog Repo-`docker-compose.yml`: Host-`cloud` → `/app/cloud`) **oder** `parse-server`-**Image neu bauen** und ausrollen. Einordnung, Klasse **`FAQ`** vs. Legacy-Namen, Paging der FAQ-Liste: [`Documentation/HELP_N_INSTRUCTIONS_SERVER_DRIVEN.md`](../HELP_N_INSTRUCTIONS_SERVER_DRIVEN.md).

### 8.3) FAQ: englische Texte von Legacy-Spalten migrieren (`migrateFAQEnglishFields`)

**Hintergrund:** Optional englische FAQ-Texte lagen historisch in den falsch benannten Spalten `questionDe` / `answerDe`. Kanonisch sind **`questionEn` / `answerEn`** (siehe `backend/parse-server/cloud/functions/user/faqLocales.js`). `getFAQs` liefert bereits zusammengeführte Werte; diese Migration schreibt die Daten in MongoDB um und entfernt die Legacy-Keys.

**Berechtigung:** Die Cloud Function erlaubt entweder einen **eingeloggten** Admin mit Berechtigung `manageTemplates` oder einen Aufruf mit **Parse Master Key** (`request.master`), damit ein Einmal-Job vom Server aus ohne Browser-Session möglich ist.

**Sicherheit:** Master Key **nur** auf dem Host aus `/home/io/fin1-server/backend/.env` lesen; **nicht** in Tickets, Chat oder Git committen. Aufruf über **`127.0.0.1:1338`** (localhost-Binding von `parse-server`), nicht über das LAN exponieren.

**Ablauf (auf `iobox`):**

```bash
cd /home/io/fin1-server/backend
APP_ID=$(grep -E '^PARSE_SERVER_APPLICATION_ID=' .env | head -1 | cut -d= -f2- | tr -d "\"'" | tr -d '\r')
MK=$(grep -E '^PARSE_SERVER_MASTER_KEY=' .env | head -1 | cut -d= -f2- | tr -d "\"'" | tr -d '\r')

# 1) Simulation (keine Schreibzugriffe)
curl -sS "http://127.0.0.1:1338/parse/functions/migrateFAQEnglishFields" \
  -H "X-Parse-Application-Id: $APP_ID" \
  -H "X-Parse-Master-Key: $MK" \
  -H "Content-Type: application/json" \
  -d '{"dryRun":true}'

# 2) Ausführung (nach Prüfung der JSON-Antwort von Schritt 1)
curl -sS "http://127.0.0.1:1338/parse/functions/migrateFAQEnglishFields" \
  -H "X-Parse-Application-Id: $APP_ID" \
  -H "X-Parse-Master-Key: $MK" \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Antwort:** u. a. `copiedFromLegacy`, `strippedLegacyOnly`, `examined`, `dryRun`. Ein zweites `dryRun` sollte nach erfolgreichem Lauf überall **`0`** melden, wenn keine Legacy-Daten mehr übrig sind.

**Deploy:** Cloud-Code wie üblich nach `/home/io/fin1-server/backend/` übertragen und `parse-server` neu laden (siehe Abschnitt 8).

### 8.4) FAQ: JSON‑Import und DEV‑Baseline‑Reset (`importFAQBackup`, `devResetFAQsBaseline`)

**Import (Restore):** Cloud Function `importFAQBackup` — spielt ein JSON ein, das dem Export (`exportFAQBackup`) entspricht (`categories[]`, `faqs[]`). Ablauf im Admin‑Portal: Datei wählen → **Dry‑Run** → Bestätigung → Schreiblauf. Zuordnung: **Kategorien** per `slug`, **FAQs** per `faqId`. Nicht auflösbare Kategorie‑Referenzen erzeugen **Warnungen** in der Antwort; betroffene FAQs können übersprungen werden.

**Development Maintenance:** `devResetFAQsBaseline` — wie bei Rechtstexten eine **bewusst destruktive** DEV‑Pflege (Sicherheits‑JSON im Response‑Body, dann Klonen der **aktiven** FAQs `isPublished` und nicht archiviert, Hard‑Delete der bisherigen aktiven Zeilen und **aller inaktiven** FAQs). Optionaler Parameter `deleteInactiveCategories: true` entfernt zusätzlich **inaktive** `FAQCategory`‑Zeilen (`isActive === false`); Standard ist **ohne** Kategorielöschung.

**ENV (Parse‑Container, typisch `~/fin1-server/backend/.env`):**

- `ALLOW_FAQ_HARD_DELETE=true` — zwingend für `devResetFAQsBaseline` und für Hard‑Deletes mit Kontext `allowFaqHardDelete` / `allowFaqCategoryHardDelete`.
- Wenn `NODE_ENV=production`: zusätzlich `ALLOW_FAQ_HARD_DELETE_IN_PRODUCTION=true`, sonst blocken die `beforeDelete`‑Trigger auf `FAQ` / `FAQCategory`.

**Verifikation im Container:**

```bash
docker exec fin1-parse-server sh -lc 'printenv ALLOW_FAQ_HARD_DELETE ALLOW_FAQ_HARD_DELETE_IN_PRODUCTION NODE_ENV'
```

Nach Änderung an `.env`: `docker compose -f docker-compose.production.yml up -d parse-server` (Container neu erzeugen, damit Variablen geladen werden).

**Hard‑Delete‑Schutz:** `cloud/triggers/faq.js` — normales Löschen ist untersagt; **Seed** nutzt `context: { allowFaqSeedDelete: true }` (siehe `cloud/functions/seed/faq/helpers.js`).

## 8.1) Troubleshooting (Parse Server Start)

### Symptom: `fin1-parse-server` startet nicht / Restart-Loop

Schnellcheck:

- Logs:
  - `docker compose -f docker-compose.production.yml logs --tail=200 parse-server`
- Status:
  - `docker compose -f docker-compose.production.yml ps parse-server`

#### Fall A: `Cannot find module 'parse-server-redis-cache-adapter'`

- **Ursache**: In `backend/parse-server/index.js` war ein Cache-Adapter als externes Modul konfiguriert, das im Image nicht existiert/aus dem Registry nicht installierbar ist.
- **Fix (empfohlen)**: Den eingebauten Redis-Cache-Adapter aus `parse-server` verwenden (`RedisCacheAdapter`) oder den Cache-Adapter komplett entfernen, wenn Redis-Caching nicht benötigt wird.
- **Hinweis**: Redis-Caching ist optional und sollte nur aktiviert werden, wenn `REDIS_URL` korrekt gesetzt ist (z.B. `redis://:<password>@redis:6379`, passend zu `REDIS_PASSWORD`/`--requirepass`).

#### Fall B: Parse ok, aber extern `https://<host>/parse/health` ist down

- Wenn `curl -sk https://localhost/health` **ok** ist, aber `curl -sk https://192.168.178.24/parse/health` **failt**:
  - prüfe `fin1-nginx`:
    - `docker compose -f docker-compose.production.yml ps nginx`
    - ggf. starten: `docker compose -f docker-compose.production.yml up -d nginx`

## 9) Backup & Restore

**Vollständige Anleitung:** `scripts/BACKUP_RESTORE.md` (im Repo). Auf dem Server: `/home/io/fin1-server/scripts/`.

### Backup (automatisch)

- Script: `/home/io/fin1-server/scripts/backup.sh`
- Cron: täglich **3:00 Uhr** (`crontab -l` prüfen)
- Zielverzeichnis: `/home/io/fin1-backups/<BACKUP_ID>/` (z. B. `20260223_124944`)
- Inhalt: MongoDB (mongodump, .gz), PostgreSQL (pg_dump, .sql.gz), Redis (dump.rdb), Config (docker-compose, .env, nginx.conf). 14 Tage Aufbewahrung.

### Restore (bestimmte Version)

- Script: `/home/io/fin1-server/scripts/restore-from-backup.sh`
- Backups anzeigen: `./scripts/restore-from-backup.sh --list`
- Vollrestore: `./scripts/restore-from-backup.sh <BACKUP_ID>` (z. B. `20260223_124944`); Bestätigung mit `yes` erforderlich.
- Nur Config: `./scripts/restore-from-backup.sh <BACKUP_ID> --config-only`
- Details und Logs: siehe `scripts/BACKUP_RESTORE.md`, `Documentation/SERVER_HARDENING_2026-02.md`.

## 10) Auto-Recovery / Service Monitoring

### Script

- `auto-start-services.sh` prüft periodisch Services und startet fehlende via `docker compose up -d <service>`.
- Log-File: `./logs/service-monitor.log` (Fallback `/tmp/fin1-service-monitor.log`)

### Systemd Unit (noch nicht aktiv)

- Datei liegt vor: `/home/io/fin1-server/service-monitor.service`
- Systemd meldet: **Unit not found** → sie ist nicht nach `/etc/systemd/system/` installiert.

Empfohlene Installation (erfordert sudo/root, daher hier nur dokumentiert):

- Copy/Symlink nach `/etc/systemd/system/service-monitor.service`
- `systemctl daemon-reload`
- `systemctl enable --now service-monitor.service`

## 11) Security Hardening (Empfehlungen aus Ist-Zustand)

Aktuell sind folgende Ports öffentlich gebunden (0.0.0.0):

- `27018` (MongoDB)
- `9002/9003` (MinIO)
- `8083/8084/8085` (Market/Notification/Analytics)

Empfehlung:

- **Firewall (ufw)**: nur LAN/Dev-IPs erlauben oder Ports auf `127.0.0.1` binden und über Nginx routen.
- Parse Dashboard extern bleibt gesperrt (ist korrekt).
- Zusätzlich sichtbar: Ports `139/445` (Samba) und `3389` (gnome remote desktop) sind offen → prüfen, ob bewusst aktiv; ansonsten schließen.
- Port `8000` ist offen → Ursache prüfen und schließen, falls nicht benötigt.

## 12) Hardening-Plan (Stufenplan, server-spezifisch)

Ziel: **Nur** `22` (SSH), `80/443` (Nginx) sind inbound nötig. Alles andere entweder:
- nur intern im Docker-Netz,
- oder nur `127.0.0.1`,
- oder per Firewall auf definierte Admin-IP(s) begrenzt.

### Stufe 0: Baseline & Safety Net

- **Backup** erstellen (inkl. DB/Config):
  - `/home/io/fin1-server/scripts/backup.sh`
- Aktuellen Zustand dokumentieren:
  - `docker compose -f docker-compose.production.yml ps`
  - `ss -ltn` (Ports)
  - `curl -sk https://localhost/health` und `curl -sk https://localhost/parse/health`

### Stufe 1: Exponierte Host-Ports reduzieren (Compose)

**Quick Wins (ohne Funktionsverlust, da Nginx intern proxy’t):**

- `market-data`, `notification-service`, `analytics-service`:
  - Host-Port-Mappings entfernen **oder** auf `127.0.0.1` binden.
  - Nginx kann weiterhin per Docker-DNS (`market-data:8080` etc.) routen.

**DB/Storage Hardening:**

- `mongodb`:
  - Port Mapping auf `127.0.0.1:27018:27017` ändern **oder** ganz entfernen.
- `minio`:
  - Wenn Console/S3 nicht aus dem LAN benötigt: auf `127.0.0.1` binden oder Port-Mappings entfernen.
  - Wenn LAN-Zugriff gewollt: Firewall-Regeln setzen (Stufe 2), sonst bleibt es eine Angriffsfläche.

Rollout:
- `docker compose -f docker-compose.production.yml up -d`
- Verify:
  - `docker compose -f docker-compose.production.yml ps`
  - `curl -sk https://192.168.178.24/health` und `curl -sk https://192.168.178.24/parse/health`
  - `ss -ltn` → prüfen, dass `8083/8084/8085` nicht mehr auf `0.0.0.0` hängen

### Stufe 2: Firewall (ufw) aktiv managen

Hinweis: Auf dem Server ist `sudo` für `io` nicht passwordless → Änderungen erfordern interaktives sudo (oder Admin-Session).

Empfohlenes Policy-Set (Beispiel):

- Default deny incoming
- allow SSH nur aus Admin-LAN (oder spezifische IP)
- allow 80/443 aus LAN (oder 0.0.0.0 wenn bewusst öffentlich)
- explizit deny/limit für DB/MinIO/808x, falls noch exposed

### Stufe 3: Nicht benötigte OS-Dienste schließen

- Samba:
  - Wenn keine NAS/SMB Nutzung notwendig: `smbd`/`nmbd` disable/stop → Ports 139/445 schließen.
- Remote Desktop:
  - `gnome-remote-desktop` (Port 3389) deaktivieren, wenn keine GUI-Remote-Administration gebraucht wird.
- Port 8000:
  - Prozess identifizieren (root/sudo nötig) und Dienst deaktivieren oder Binding auf localhost ändern.

### Stufe 4: Go/No-Go & Regression Checks

- Health: `/health` und `/parse/health`
- App-Funktionalität: iOS Verbindung (Parse REST + LiveQuery) via `https://192.168.178.24/parse` und `wss://192.168.178.24/parse`
- Dashboard Zugriff: nur via SSH Tunnel (`ssh -L 443:127.0.0.1:443 io@<server>` → `https://localhost/dashboard/`)
- Keine unerwarteten offenen Ports: `ss -ltn` Review

### Rollback-Strategie

- Compose: Port-Mappings zurücksetzen und `docker compose up -d`
- Firewall: letzte Regeländerungen revert
- Services: re-enable falls notwendig (Samba/Remote Desktop)

## 13) Konkrete Compose-Änderungen (Patch-Vorschläge)

Ziel: **Keine unnötigen Host-Ports** auf `0.0.0.0`. Wenn Nginx intern (Docker-Netz) routen kann, sind Host-Port-Mappings für interne Services nicht nötig.

Quelle (Ist): `/home/io/fin1-server/docker-compose.production.yml`

### 13.1 Quick Wins: 8083/8084/8085 schließen, ohne API zu verlieren

Nginx nutzt Docker-DNS/Service-Namen (`market-data`, `notification-service`, `analytics-service`) – dafür braucht es **keine** Host-Ports.

**Option A (empfohlen): Host-Port-Mappings komplett entfernen**

- `market-data`:
  - **entferne** `ports:` Block (`"8083:8080"`)
- `notification-service`:
  - **entferne** `ports:` Block (`"8084:8081"`)
- `analytics-service`:
  - **entferne** `ports:` Block (`"8085:8082"`)

Auswirkungen:
- ✅ Zugriff weiterhin über Nginx:
  - `/api/market-data/`, `/api/notifications/`, `/api/analytics/`
- ❌ Direkter Zugriff via `http(s)://<host>:8083/...` entfällt (Port nur 127.0.0.1, gewollt).

**Option B: Nur localhost binden (wenn du direkte Debug-Calls brauchst)**

- `market-data`:
  - `"8083:8080"` → `"127.0.0.1:8083:8080"`
- `notification-service`:
  - `"8084:8081"` → `"127.0.0.1:8084:8081"`
- `analytics-service`:
  - `"8085:8082"` → `"127.0.0.1:8085:8082"`

### 13.2 MongoDB (27018) hardenen

Ist: `"0.0.0.0:27018:27017"` (LAN-weit offen)

**Option A (empfohlen): nur localhost**

- `"0.0.0.0:27018:27017"` → `"127.0.0.1:27018:27017"`

Auswirkungen:
- ✅ Parse Server (im Docker-Netz) hat weiterhin Zugriff auf MongoDB (Container-to-Container).
- ✅ Admin-Zugriff ist weiterhin möglich, aber nur über:
  - SSH Tunnel (Port Forward) oder Login am Server.

**Option B: komplett entfernen (maximal sicher)**

- entferne den `ports:` Block bei `mongodb`

### 13.3 MinIO (9002/9003) hardenen

Ist:
- `"9002:9000"` (S3)
- `"9003:9001"` (Console)

**Option A (empfohlen): nur localhost**

- `"9002:9000"` → `"127.0.0.1:9002:9000"`
- `"9003:9001"` → `"127.0.0.1:9003:9001"`

**Option B: nur S3 extern, Console nur localhost**

- `"9002:9000"` bleibt (oder LAN-restricted via Firewall)
- `"9003:9001"` → `"127.0.0.1:9003:9001"`

### 13.4 Parse Server (1338)

Ist bereits korrekt gehärtet:

- `"127.0.0.1:1338:1337"` (nur localhost)

Beibehalten, Nginx ist der External Entry Point (`/parse`).

### 13.5 Rollout / Verify / Rollback (Compose)

- **Rollout**
  - `cd /home/io/fin1-server`
  - `docker compose -f docker-compose.production.yml up -d`
- **Verify**
  - `docker compose -f docker-compose.production.yml ps`
  - extern (LAN): `curl -sk https://192.168.178.24/health` und `curl -sk https://192.168.178.24/parse/health`
  - Ports: `ss -ltn` (keine `0.0.0.0:27018`, `:9002`, `:9003`, `:8083`, `:8084`, `:8085`)
- **Rollback**
  - Compose-Datei zurücksetzen
  - `docker compose -f docker-compose.production.yml up -d`

## 14) Firewall/UFW Checkliste (inkl. Docker-Sonderfall)

Wichtig: Auf `iobox` ist `sudo` für User `io` **nicht** passwordless. Für folgende Schritte brauchst du interaktives sudo oder eine Admin-Session.

### 14.1 Grundregel: Erst SSH erlauben, dann UFW aktivieren

Bevor `ufw enable`:

- `ufw allow OpenSSH`
- oder restriktiver: `ufw allow from 192.168.178.0/24 to any port 22 proto tcp`

Sonst riskierst du Lockout.

### 14.2 Minimal-Policy (Zielzustand)

Empfohlen (Beispiel, LAN-only):

- Default deny incoming:
  - `ufw default deny incoming`
- Default allow outgoing:
  - `ufw default allow outgoing`
- Allow SSH (LAN):
  - `ufw allow from 192.168.178.0/24 to any port 22 proto tcp`
- Allow HTTP/HTTPS:
  - LAN-only: `ufw allow from 192.168.178.0/24 to any port 80,443 proto tcp`
  - oder öffentlich (wenn gewollt): `ufw allow 80/tcp` und `ufw allow 443/tcp`

**Explizit blocken (falls noch offen):**

- Mongo: `27018/tcp`
- MinIO: `9002/tcp`, `9003/tcp`
- Service-Ports: `8083/tcp`, `8084/tcp`, `8085/tcp`
- Unklare Ports: `8000/tcp`
- Samba: `139/tcp`, `445/tcp` (nur wenn SMB nicht benötigt)
- Remote Desktop: `3389/tcp` (nur wenn nicht benötigt)

### 14.3 Docker-Sonderfall: UFW blockt published Ports oft nicht zuverlässig

Docker fügt iptables-Regeln ein, die UFW “umgehen” können, insbesondere bei `ports:` auf `0.0.0.0`.

**Best Practice für FIN1:**

1. **Primär**: Host-Port-Exposure über Compose reduzieren (siehe Abschnitt 13).
2. **Sekundär**: Defense-in-depth über Firewall.

Wenn du trotzdem docker-published Ports per Firewall einschränken willst, ist der robuste Weg die **`DOCKER-USER` chain**:

- Beispiel (Drop für Mongo Port 27018 auf eth0):
  - `iptables -I DOCKER-USER -i eth0 -p tcp --dport 27018 -j DROP`

Hinweise:
- Regeln müssen persistent gemacht werden (z.B. `iptables-persistent`/`netfilter-persistent`), sonst gehen sie nach Reboot verloren.
- Nur anwenden, wenn du genau weißt, welche Interfaces/Ports betroffen sind.

### 14.4 Samba/RDP konkrete Findings (Ist-Zustand)

- Samba:
  - Services `smbd` und `nmbd` sind **enabled + active**.
  - Ports `139/445` sind offen.
  - Wenn nicht benötigt: disable/stop + Firewall schließen.
- RDP:
  - Port `3389` wird von `gnome-remote-desktop` geöffnet (User `io`).
  - Wenn nicht benötigt: Remote Desktop deaktivieren und Port schließen.

### 14.5 Quick Verify Checklist nach Hardening

- `docker compose ps` → alles healthy
- `curl -sk https://192.168.178.24/health` → 200
- `curl -sk https://192.168.178.24/parse/health` → 200
- `ss -ltn`:
  - nur `22`, `80`, `443` (und ggf. bewusst erlaubte Admin-Ports) auf `0.0.0.0`
  - Parse `1338` bleibt localhost

## 15) Copy/Paste Snippets (YAML) – `docker-compose.production.yml`

> Diese Snippets sind so kurz wie möglich gehalten. Du kannst sie direkt in `/home/io/fin1-server/docker-compose.production.yml` übertragen.

### 15.1 `market-data` (8083)

**IST**

```yaml
  market-data:
    ports:
      - "8083:8080"
```

**SOLL (Option A: Ports entfernen)**

```yaml
  market-data:
    # ports: entfernt (Zugriff via Nginx /api/market-data/)
```

**SOLL (Option B: nur localhost)**

```yaml
  market-data:
    ports:
      - "127.0.0.1:8083:8080"
```

### 15.2 `notification-service` (8084)

**IST**

```yaml
  notification-service:
    ports:
      - "8084:8081"
```

**SOLL (Option A: Ports entfernen)**

```yaml
  notification-service:
    # ports: entfernt (Zugriff via Nginx /api/notifications/)
```

**SOLL (Option B: nur localhost)**

```yaml
  notification-service:
    ports:
      - "127.0.0.1:8084:8081"
```

### 15.3 `analytics-service` (8085)

**IST**

```yaml
  analytics-service:
    ports:
      - "8085:8082"
```

**SOLL (Option A: Ports entfernen)**

```yaml
  analytics-service:
    # ports: entfernt (Zugriff via Nginx /api/analytics/)
```

**SOLL (Option B: nur localhost)**

```yaml
  analytics-service:
    ports:
      - "127.0.0.1:8085:8082"
```

### 15.4 `mongodb` (27018)

**IST**

```yaml
  mongodb:
    ports:
      - "0.0.0.0:27018:27017"
```

**SOLL (Option A: nur localhost)**

```yaml
  mongodb:
    ports:
      - "127.0.0.1:27018:27017"
```

**SOLL (Option B: Ports entfernen)**

```yaml
  mongodb:
    # ports: entfernt (Zugriff nur im Docker-Netz)
```

### 15.5 `minio` (9002/9003)

**IST**

```yaml
  minio:
    ports:
      - "9002:9000"
      - "9003:9001"
```

**SOLL (Option A: nur localhost)**

```yaml
  minio:
    ports:
      - "127.0.0.1:9002:9000"
      - "127.0.0.1:9003:9001"
```

**SOLL (Option B: S3 extern, Console localhost)**

```yaml
  minio:
    ports:
      - "9002:9000"
      - "127.0.0.1:9003:9001"
```

### 15.6 `parse-server` (1338) – Referenz (bereits korrekt)

**IST/SOLL**

```yaml
  parse-server:
    ports:
      - "127.0.0.1:1338:1337"
```


