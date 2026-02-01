---
title: "FIN1 – START HERE (aktueller Projektstand, 5–20 Minuten)"
audience: ["Entwicklung", "QA", "Betrieb/Netzwerk", "Produkt/Marketing", "Support/CSR", "Stakeholder"]
lastUpdated: "2026-02-01"
---

## Ziel

Eine sachkundige dritte Person (oder eine IDE wie Cursor) soll den **aktuellen Stand von FIN1** schnell und zuverlässig verstehen – ohne in hunderten Markdown-Dateien zu versinken.

## 0) 1‑Minute Briefing (für den schnellen Überblick)

- **Produkt**: FIN1 ist eine iOS Investment-/Trading-Plattform mit Rollen **Investor** und **Trader** (plus Admin/CSR/Compliance).
- **Stack**: iOS (SwiftUI, MVVM + DI über `AppServices`), Backend (Docker, Nginx, Parse Server/Cloud Code, MongoDB, Redis, Postgres optional, MinIO optional).
- **Aktueller Projektstand**: `FIN1_PROJECT_STATUS.md` (Historie via Git).
- **Wichtigste URLs (LAN, iobox)**:
  - API: `http://192.168.178.24/parse`
  - LiveQuery: `ws://192.168.178.24/parse`
  - Health: `http://192.168.178.24/health`
  - Dashboard: **nur per SSH‑Tunnel** (siehe `FIN1_PROJECT_STATUS.md` + `Documentation/FIN1_APP_DOCS/06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md`)
- **Doku-Startpunkte**:
  - Kuratierte Gesamtdoku: `Documentation/FIN1_APP_DOCS/00_INDEX.md`
  - Wichtige Snapshots (v2026‑01‑30/31): `Documentation/SNAPSHOTS_INDEX.md`

## 1) Der schnellste Einstieg (5 Minuten)

1. **Aktueller Projektstatus (Kurzüberblick)**
   - Pointer: `FIN1_PROJECT_STATUS.md`
2. **Kuratierte Gesamtdoku (zielgruppenorientiert, “Current”)**
   - Startpunkt: `Documentation/FIN1_APP_DOCS/00_INDEX.md`
3. **Snapshots-Index (für alle wichtigen v2026-01-30/31 Dateien)**
   - `Documentation/SNAPSHOTS_INDEX.md`

## 2) Je Rolle: Was lesen / wo anfangen?

- **iOS Entwickler**
  - `Documentation/FIN1_APP_DOCS/04_DEVELOPER_GUIDE.md`
  - `Documentation/FIN1_APP_DOCS/03_TECHNISCHE_SPEZIFIKATION.md`
  - “Do-not-break” Invarianten: `Documentation/FIN1_APP_DOCS/02A_FEATURE_KATALOG_GUARDRAILS.md`

- **Backend Entwickler**
  - `backend/README.md` (Quickstart)
  - `Documentation/FIN1_APP_DOCS/06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md` (Production/Server-Realität)
  - `Documentation/FIN1_APP_DOCS/03_TECHNISCHE_SPEZIFIKATION.md` (Cloud Functions, Datenmodell, Security)

- **Betrieb / Netzwerk / Security**
  - `Documentation/FIN1_APP_DOCS/06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md` (Ports, Nginx, SSH Tunnel, Backups, Hardening)
  - `Documentation/FIN1_APP_DOCS/06_BETRIEB_PROZESSE.md` (Release/Rollback, Monitoring)
  - Projektstatus: `FIN1_PROJECT_STATUS.md` (TL;DR URLs/Ports)

- **QA**
  - `Documentation/FIN1_APP_DOCS/05_TEST_QUALITAET.md`
  - Feature-Minimalchecks: `Documentation/FIN1_APP_DOCS/02A_FEATURE_KATALOG_GUARDRAILS.md`

- **Support/CSR**
  - `Documentation/FIN1_APP_DOCS/06B_CSR_SUPPORT_WORKFLOW.md` (Workflow + Aufgabenverteilung/RACI)
  - `Documentation/FIN1_APP_DOCS/07_USER_GUIDE.md` (User-Sicht & FAQ)

- **Produkt / Marketing / Stakeholder**
  - `Documentation/FIN1_APP_DOCS/01_PROJEKTUEBERBLICK.md` (Vision, Zielgruppen, Erfolgskriterien)
  - `Documentation/FIN1_APP_DOCS/02_REQUIREMENTS.md` (Use Cases, Regeln, NFRs)

## 3) “Current” vs. “Snapshot” (damit niemand falsche Dateien nutzt)

- **Current (lebend, kuratiert)**: `Documentation/FIN1_APP_DOCS/*.md`
- **Snapshots/Historie**: über **Git** (Commits; optional Tags für “feste Stände”)
  - Index: `Documentation/SNAPSHOTS_INDEX.md`

## 4) Für Cursor/LLMs: empfohlene Lesereihenfolge (max. Kontext, minimaler Lärm)

1. `Documentation/FIN1_APP_DOCS/00_INDEX.md`
2. `FIN1_PROJECT_STATUS.md`
3. `Documentation/FIN1_APP_DOCS/03_TECHNISCHE_SPEZIFIKATION.md`
4. Je nach Aufgabe: `04_DEVELOPER_GUIDE.md` / `06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md` / `02A_FEATURE_KATALOG_GUARDRAILS.md`

