---
title: "FIN1 – Betriebs- und Prozessdokumentation (Runbook)"
audience: ["Betrieb", "SRE/Ops", "Release Management", "Security"]
lastUpdated: "2026-05-02"
---

## Zweck

Dieses Dokument beschreibt Betrieb/Deployment der FIN1 Backend-Services sowie Release-/Rollback-Prozesse.

## ⭐ Detailliertes Ubuntu Runbook

Für den **konkreten** Serverbetrieb auf `iobox` (User `io`, Pfade, Ports, Scripts, Backups):

- `06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md`
- Deploy-Ziele (zwei LAN-IPs, Admin vs. Parse Cloud): [`../OPERATIONAL_DEPLOY_HOSTS.md`](../OPERATIONAL_DEPLOY_HOSTS.md) — `./scripts/show-fin1-deploy-targets.sh`
- **Moderne Deploy-Best-Practices** (CI-Artefakte, Images, Immutability, Secrets, Rollback, Migrationspfad von rsync): [`../MODERN_DEPLOY_BEST_PRACTICES.md`](../MODERN_DEPLOY_BEST_PRACTICES.md)

**Nächste Schritte (Prioritäten)** für Server & Operations (Restore-Test, Patching, Ports, Incident-Runbook, Deploy-Tagging): `Documentation/NAECHSTE_SCHRITTE_SERVER_OPS.md`

Hinweis: Das Runbook enthält auch einen **Hardening-Stufenplan** (Port-Exposure/Firewall/OS-Services).

## ⭐ CSR Workflow & Aufgabenverteilung

Für den **genauen** Support-Prozess (Rollen L1/L2/Fraud/Compliance/Tech/Teamlead, SLA, Auto-Eskalation, 4-Augen):

- `06B_CSR_SUPPORT_WORKFLOW.md`

## 1) Betriebs-Handbuch (Services)

### Zieltopologie (Produktion – Docker Compose)

Referenz: `docker-compose.production.yml`

- **Nginx**: :80/:443 (Reverse Proxy)
- **Nginx**: :80 (Redirect auf HTTPS), :443 (HTTPS)
- **Parse Server**: Host 127.0.0.1:1338 → Container :1337 (`/parse`, `/dashboard`, `/health`, LiveQuery)
- **MongoDB / Redis / Postgres / MinIO**: nur 127.0.0.1 (nicht von LAN erreichbar)
- **Market Data / Notification / Analytics**: 127.0.0.1:8083/8084/8085
- **Uptime Kuma (Monitoring)**: optional Port 3001
- **PDF Service**: (wenn genutzt; Base URL z.B. `:8086`)

### Start/Stop

- Start (Produktion):
  - `docker compose -f docker-compose.production.yml up -d`
- Stop:
  - `docker compose -f docker-compose.production.yml down`

### Healthchecks

- Nginx: `http://<host>/health`
- Parse: `http://<host>/parse/health` (via Nginx) oder intern `http://localhost:1337/health`
- Parse “API Docs”: `http://<host>/api-docs`
- Services (container): `http://<host>:8083/health`, `:8084/health`, `:8085/health`

### Admin-Portal: System-Seite & Finance-Konsistenz (Ops)

- **System → Status:** Ruft `getSystemHealth` auf. **Kein** automatischer „Systemausfall“ mehr bei reinem Ladefehler (Netzwerk/Session): Anzeige **„Systemstatus konnte nicht geladen werden“** (`unknown`) inkl. Fehlertext. **Retries** mit Backoff reduzieren False Positives nach Ubuntu-/Docker-Start.
- **MongoDB-Check:** Erreichbarkeit über kleines `_SCHEMA`-Probe; ein optionaler Voll-Scan aller Schemas darf die Gesundheit **nicht** mehr als „getrennt“ werten (Details: `functions/admin/system.js`).
- **System → Konsistenz-Karten:** `getTradeSettlementConsistencyStatus` (Settlement vs. `AccountStatement`), `runFinanceConsistencySmoke` (Sammel-Smoke inkl. Mirror-Basis, Ledger-Stichprobe, Beleg-Referenzen). Cloud-Code: `functions/admin/opsHealth.js`. Benchmark-Funktionen optional für Lastmessung.
- Architektur/Kontext: [`Documentation/ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md`](../ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md).

### Parse Cloud Code: Konfigurations-Modul (`configHelper`)

Beim Deploy von **`backend/parse-server/cloud/`** darf **keine** Datei **`utils/configHelper.js`** neben dem Ordner **`utils/configHelper/`** existieren: Node würde die Datei dem Paket vorziehen und **veralteten Code** laden (u. a. fehlgeschlagene Konfig-Speicherung im Admin-Portal, kaputte FAQ-Platzhalter).

- **Prävention / Skripte:** `scripts/check-parse-cloud-config-helper-shadow.sh`, Anbindung in CI und `scripts/deploy-to-ubuntu.sh` (siehe Runbook).
- **Details, Symptome, manuelle Korrektur:** [`06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md`](06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md) **§ 8.2.1**.

### Parse Dashboard – sicher betreiben

Problem: Dashboard embeded `serverURL` im Browser-Frontend. Deshalb:

- Dashboard **nicht** öffentlich exponieren.
- Zugriff über **SSH Tunnel** auf Nginx (Dashboard nur von localhost):
  - Tunnel: `ssh -L 443:127.0.0.1:443 <user>@<server>`
  - Dashboard: `https://localhost/dashboard/`
- `PARSE_DASHBOARD_SERVER_URL` auf `http://localhost:1338/parse` setzen (Server-ENV).
- `PARSE_SERVER_MASTER_KEY_IPS` restriktiv halten (z.B. localhost + Docker range).

### Parse / Admin: destruktive DEV‑Wartung (Rechtstexte & FAQs)

Cloud Functions für **Hard‑Deletes** und Baseline‑Resets sind absichtlich **nicht** ohne explizite Umgebungsvariablen nutzbar (Schutz vor Datenverlust).

| Variable | Wirkung |
|----------|---------|
| `ALLOW_LEGAL_HARD_DELETE` | Erlaubt u. a. `devResetLegalDocumentsBaseline` (TermsContent hart löschen im definierten Ablauf). |
| `ALLOW_LEGAL_HARD_DELETE_IN_PRODUCTION` | Nur nötig, wenn `NODE_ENV=production` **und** Legal‑DEV‑Reset trotzdem ausgeführt werden soll. |
| `ALLOW_FAQ_HARD_DELETE` | Erlaubt `devResetFAQsBaseline` sowie kontextgeführte Hard‑Deletes auf `FAQ` / `FAQCategory` (siehe Trigger `cloud/triggers/faq.js`). |
| `ALLOW_FAQ_HARD_DELETE_IN_PRODUCTION` | Nur nötig, wenn `NODE_ENV=production` **und** FAQ‑DEV‑Reset trotzdem ausgeführt werden soll. |

**Betrieb:** Variablen in `backend/.env` des Compose‑Stacks setzen, **`parse-server`‑Container neu erstellen/starten** (`docker compose … up -d parse-server`), damit die Werte im Container ankommen. Details und Verifikation: `06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md` (FAQ § 8.4, Legal siehe `LEGAL_DOCS_AUDIT_TRAIL.md`).

## 2) Backup/Restore

**Automatisches Backup (Produktion):** Täglich 3:00 Uhr auf dem Server (Cron). Inhalt: MongoDB, PostgreSQL, Redis, Config. 14 Tage Aufbewahrung. Siehe `scripts/BACKUP_RESTORE.md`.

**Bestimmte Backup-Version wiederherstellen:**

- Auf dem Server: `./scripts/restore-from-backup.sh --list` (Backups anzeigen), dann `./scripts/restore-from-backup.sh <BACKUP_ID>` (z. B. `20260223_124944`).
- Vollständige Anleitung: `scripts/BACKUP_RESTORE.md`. Restore-Script: `scripts/restore-from-backup.sh`.

### MongoDB (Parse Primary DB)

- Backup: automatisch via `scripts/backup.sh` (mongodump --gzip).
- Restore: `restore-from-backup.sh <BACKUP_ID>` (nutzt mongorestore --drop).

### Postgres (Analytics)

- Backup: automatisch via `scripts/backup.sh` (pg_dump, nicht pg_dumpall).
- Restore: `restore-from-backup.sh <BACKUP_ID>` (DROP/CREATE DB + Einspielen des Dumps).

### Redis

- Backup: RDB-Snapshot im Backup-Verzeichnis.
- Restore: Script ersetzt dump.rdb und startet Redis neu.

Operational: Regelmäßige Restore-Tests empfohlen (siehe `Documentation/SERVER_HARDENING_2026-02.md`).

## 3) Skalierung

Typisch:
- Parse Server horizontal skalierbar (Load Balancing über Nginx), DB/Redis müssen passend dimensioniert sein.
- Redis/Postgres/Mongo: eher vertikal + ggf. repliziert (Roadmap).

## 4) Logging & Monitoring

### Logging

- Container Logs (json-file / Rotation empfohlen)
- Parse Logs: `/app/logs` Volume (siehe Compose)
- Nginx Access/Error Logs: `./logs/nginx`

### Monitoring/Alerts (Minimum)

- **Uptime Kuma** (Container, Port 3001): 8 Monitore (Parse, Nginx, Microservices, MongoDB, Redis, Postgres). Alerts z. B. via ntfy. Siehe `Documentation/SERVER_HARDENING_2026-02.md`.
- Uptime Checks: `https://<host>/health` (Nginx) + `/parse/health`
- Error Rate: 5xx/4xx in Parse, Cloud Function Fehler
- DB Health: Mongo ping, Redis ping, Postgres readiness
- Disk: Volumes für Mongo/Postgres/Logs

### Return%-Contract: operative Guardrails (verbindlich)

- **Daily monitor:** `/home/io/fin1-server/scripts/run-return-monitor.sh`
  - cron: täglich
  - plus `@reboot` catch-up für nicht dauerhaft laufende Server
- **Heartbeat/Alert-Spuren:**
  - `/home/io/fin1-server/logs/return-monitor.heartbeat`
  - `/home/io/fin1-server/logs/return-monitor.alert`
  - syslog tag: `fin1-return-monitor`
- **Weekly reconciliation:** `/home/io/fin1-server/scripts/run-return-reconciliation.sh`
  - cron: wöchentlich
  - plus `@reboot` catch-up
- **Auth-smoke-test vor kritischen Releases:**
  - `scripts/smoke-audit-return-percentage-auth.sh` (real admin session token, kein master key)
- **DB boundary validator (active collection bills):**
  - `backend/scripts/apply-document-return-percentage-validator.js`

## 5) Release-Prozess

### Go/No-Go Kriterien (Backend)

- Healthchecks grün
- **Repository-CI:** Für Änderungen am Admin-Web-Portal GitHub-Job **`admin-portal`** grün (Lint, Vitest, Build)
- Keine neuen High/Critical Findings (Security/Compliance)
- Smoke Tests (kritische Cloud Functions) erfolgreich:
  - `getConfig`, `getCurrentLegalDocument`, `createInvestment/confirmInvestment`, `placeOrder`
- Backup aktuell und geprüft

### Rollback-Strategie

- Docker Image Tagging (empfohlen): immutable tags pro Release
- Rollback:
  - Compose auf vorherigen Tag zurücksetzen
  - DB-Migrationen: bevorzugt **forward-only** oder vorherige Restore-Option dokumentieren

### iOS Release (App Store)

- Scheme `FIN1-Prod`, Build Number erhöhen
- Lokale Quality Gates: SwiftFormat/SwiftLint/Build/Tests
- Release Notes + Compliance Check (Legal/Privacy) verifizieren

## 6) Support & Wartung

### 1st/2nd-Level

- 1st-Level: Ticketaufnahme, Standard-Troubleshooting, Statuskommunikation.
- 2nd-Level: technische Analyse (Logs/DB), Bugfix/HOTFIX, Datenkorrekturen (auditpflichtig).

### Priorisierung (SLA-orientiert)

- S0: Trading/Legal komplett down
- S1: kritischer Flow betroffen (Order Placement, Investment Activation, Consent)
- S2: Degradation/Einzelfälle
- S3: Cosmetic/Low impact

### Wartungsfenster

- Planbar, kommuniziert, Rollback bereit, Monitoring währenddessen erhöht.

## 7) CI / Repository-Qualität (GitHub Actions)

Workflow: **`.github/workflows/ci.yml`** (Branches `main` / `master` und zugehörige PRs).

| Job | Runner | Inhalt (Kurz) |
|-----|--------|----------------|
| **`admin-portal`** | `ubuntu-latest`, Node 20 | Im Verzeichnis `admin-portal/`: `npm ci` → **`npm run lint`** (ESLint 9 Flat Config) → **`npm run test:run`** (Vitest) → **`npm run build`** (`tsc` + Vite; Postbuild synchronisiert `dist/` nach `admin/` im Repo) |
| **`build-test-lint`** | `macos-14` | SwiftFormat, SwiftLint, Xcode Build & Tests (Simulator), ggf. Danger auf PRs |

**Release-Hinweis:** Vor einem Release, das das Admin-Web-Portal betrifft, sollte der Job **`admin-portal`** grün sein (keine bewusst ignorierten Lint-/Testfehler). Details zur Portal-Funktion: `FIN1_APP_DOCS/10_ADMIN_PORTAL_REQUIREMENTS.md`; Entwickler-Quickstart: `admin-portal/README.md`.

## 8) Admin-Web-Portal (statisches Frontend)

- **Build:** lokal oder in CI wie oben; Artefakt: `admin-portal/dist/` (wird per `postbuild` nach `admin/` gespiegelt).
- **Deploy auf den Server:** üblich rsync/scp von `admin/` (oder `dist/`) gemäß Nginx-`alias` (siehe `10_ADMIN_PORTAL_REQUIREMENTS.md` §5, `DEPLOYMENT_RSYNC_SICHERHEIT.md`).
- **Kein** separater Node-Prozess im Betrieb (reines Static Hosting hinter Nginx).

