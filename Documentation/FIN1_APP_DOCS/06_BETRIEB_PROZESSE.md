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

Hinweis: Das Runbook enthält auch einen **Hardening-Stufenplan** (Port-Exposure/Firewall/OS-Services).

## ⭐ CSR Workflow & Aufgabenverteilung

Für den **genauen** Support-Prozess (Rollen L1/L2/Fraud/Compliance/Tech/Teamlead, SLA, Auto-Eskalation, 4-Augen):

- `06B_CSR_SUPPORT_WORKFLOW.md`

## 1) Betriebs-Handbuch (Services)

### Zieltopologie (Produktion – Docker Compose)

Referenz: `docker-compose.production.yml`

- **Nginx**: :80/:443 (Reverse Proxy)
- **Parse Server**: Host :1338 → Container :1337 (`/parse`, `/dashboard`, `/health`, LiveQuery)
- **MongoDB**: Host :27018 → :27017
- **Redis**: Host :6380 (localhost only) → :6379
- **Postgres**: Host :5433 (localhost only) → :5432
- **MinIO**: :9002/:9003
- **Market Data**: :8083
- **Notification Service**: :8084
- **Analytics Service**: :8085
- **PDF Service**: (im Status-Dokument erwähnt; Base URL z.B. `:8086`)

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
- Zugriff über **SSH Tunnel** auf `localhost`:
  - Tunnel: `ssh -L 1338:127.0.0.1:1338 <user>@<server>`
  - Dashboard: `http://localhost:1338/dashboard`
- `PARSE_DASHBOARD_SERVER_URL` auf `http://localhost:1338/parse` setzen.
- `PARSE_SERVER_MASTER_KEY_IPS` restriktiv halten (z.B. localhost + Docker range).

## 2) Backup/Restore

### MongoDB (Parse Primary DB)

- Backup (Beispiel):
  - `mongodump` aus Container, Volume/Host-Path als Ziel
- Restore:
  - `mongorestore`

Operational requirements:
- Backups verschlüsseln, Zugriff restriktiv, regelmäßige Restore-Tests.

### Postgres (Analytics)

- Backup: `pg_dump`
- Restore: `psql` / `pg_restore`

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

- Uptime Checks: `/health` (Nginx) + `/parse/health`
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

