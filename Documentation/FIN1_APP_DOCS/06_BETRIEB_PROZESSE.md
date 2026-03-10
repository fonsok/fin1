---
title: "FIN1 – Betriebs- und Prozessdokumentation (Runbook)"
audience: ["Betrieb", "SRE/Ops", "Release Management", "Security"]
lastUpdated: "2026-02-01"
---

## Zweck

Dieses Dokument beschreibt Betrieb/Deployment der FIN1 Backend-Services sowie Release-/Rollback-Prozesse.

## ⭐ Detailliertes Ubuntu Runbook

Für den **konkreten** Serverbetrieb auf `iobox` (User `io`, Pfade, Ports, Scripts, Backups):

- `06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md`

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

### Parse Dashboard – sicher betreiben

Problem: Dashboard embeded `serverURL` im Browser-Frontend. Deshalb:

- Dashboard **nicht** öffentlich exponieren.
- Zugriff über **SSH Tunnel** auf Nginx (Dashboard nur von localhost):
  - Tunnel: `ssh -L 443:127.0.0.1:443 <user>@<server>`
  - Dashboard: `https://localhost/dashboard/`
- `PARSE_DASHBOARD_SERVER_URL` auf `http://localhost:1338/parse` setzen (Server-ENV).
- `PARSE_SERVER_MASTER_KEY_IPS` restriktiv halten (z.B. localhost + Docker range).

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

## 5) Release-Prozess

### Go/No-Go Kriterien (Backend)

- Healthchecks grün
- Keine neuen High/Critical Findings (Security/Compliance)
- Smoke Tests (kritische Cloud Functions) erfolgreich:
  - `getConfig`, `getCurrentLegalDocument`, `createInvestment/confirmInvestment`, `placeOrder`, `getWalletBalance`
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

- S0: Trading/Wallet/Legal komplett down
- S1: kritischer Flow betroffen (Order Placement, Investment Activation, Consent)
- S2: Degradation/Einzelfälle
- S3: Cosmetic/Low impact

### Wartungsfenster

- Planbar, kommuniziert, Rollback bereit, Monitoring währenddessen erhöht.

