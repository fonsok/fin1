---
title: "FIN1 – Snapshots/Tags Index"
audience: ["Alle"]
lastUpdated: "2026-02-01"
---

## Zweck

Dieser Index reduziert “Doku-Verwirrung”, indem er die **wichtigsten Einstiegspunkte** und die empfohlene **Git-Snapshot-Strategie** an einer Stelle bündelt.

## 1) Startpunkte (“Current”)

- Repo-Start: `START_HERE.md`
- Projektstatus (TL;DR): `FIN1_PROJECT_STATUS.md`
- Kuratierte App-Doku: `Documentation/FIN1_APP_DOCS/00_INDEX.md`

## 2) Snapshots (ohne `-v...` Dateinamen)

In FIN1 werden Snapshots nicht über Dateinamen-Versionierung gemacht, sondern über **Git**:

- **Commit** = ein konkreter Stand
- **Tag** = ein “fester” Name für einen wichtigen Stand (optional)

Beispiel (lokal, ohne GitHub):

```bash
git tag -a docs-2026-02-01 -m "Docs snapshot 2026-02-01"
git tag --list "docs-*"
```

## 3) Häufige Referenzen (Dateien)

- Nächste Schritte: `NAECHSTE_SCHRITTE.md`
- Dashboard/Parse Guides:
  - `DASHBOARD_ANLEITUNG.md`
  - `DASHBOARD_SCHRITT_FUER_SCHRITT.md`
  - `DASHBOARD_TROUBLESHOOTING.md`
  - `DASHBOARD_ALTERNATIVE.md`
- ComplianceEvent Setup: `COMPLIANCE_EVENT_SETUP.md`

