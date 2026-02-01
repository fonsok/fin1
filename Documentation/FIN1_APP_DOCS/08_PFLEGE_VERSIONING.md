---
title: "FIN1 – Struktur, Form und Pflege der Dokumentation"
audience: ["Alle"]
lastUpdated: "2026-02-01"
---

## Zweck

Diese Regeln sorgen dafür, dass die FIN1-Dokumentation **konsistent**, **modular** und **wartbar** bleibt – insbesondere, weil im Repo bereits historische Dokumente und versionierte Varianten existieren.

## 1) Einheitliche Struktur (pro Dokument)

Jedes Dokument folgt (wo sinnvoll) dieser Kapitelstruktur:

- **Zweck** (warum existiert dieses Dokument?)
- **Zielgruppe** (wer liest es primär?)
- **Voraussetzungen / Kontext**
- **Inhalt** (Schritte/Regeln/Beispiele)
- **Referenzen** (Codepfade, andere Docs)
- **Changelog** (optional, bei häufigen Änderungen)

## 2) Modularer Aufbau (kleine Bausteine)

- Ein Dokument = ein klarer Verantwortungsbereich (z.B. Requirements vs. Ops Runbook).
- Vermeide “Mega-Markdown” mit 3000 Zeilen; verlinke stattdessen.
- Code-Details gehören in technische Spezifikation/Anhänge, nicht in Stakeholder-Docs.

## 3) Versions- und Änderungsmanagement

### “Current” vs. “Snapshot”

In FIN1 werden Dokumente **ohne Versionssuffix im Dateinamen** gepflegt.

- `Documentation/FIN1_APP_DOCS/*.md` ist **Current** (lebende Dokumentation).
- Root-Entry-Doks sind ebenfalls **Current** (z.B. `START_HERE.md`, `FIN1_PROJECT_STATUS.md`).

### Git ergänzend nutzen (ohne GitHub-Zwang)

Das Projekt ist bereits ein **Git-Repository**. Dafür ist **keine GitHub-Anmeldung** nötig.

Empfehlung: Nutzt Git als Historie/Snapshot-Mechanismus:

- Änderungen passieren in den **Current** Dateien (ohne `-v...`).
- Wichtige Stände werden per **Git-Tag** markiert (optional), z.B.:

- `docs-v2026-01-31`

So findet man den Stand robust über **Git-Commits/Tags**, ohne Doppelquellen durch Dateikopien.

### App-Version Zuordnung

Empfehlung:
- In Release Notes/Tag/Changelog referenziert ihr:
  - die App-Version (z.B. `1.3.0 (123)`)
  - die zugehörige Doku-Snapshot-Version (falls vorhanden)

### Änderungsprozess

- Änderungen an Requirements/Compliance/Legal müssen per Review erfolgen:
  - PO + Compliance (fachlich)
  - Tech Leads (technisch)
  - QA (Testbarkeit/Abnahmekriterien)

## 4) Klare Sprache & Terminologie

- Aktiv, kurze Sätze.
- **Sprachen-Regel (verbindlich)**:
  - Dokumentation ist **nur Deutsch und/oder Englisch**.
  - Keine zufälligen Fremdsprachen-/Unicode-Mixes (z.B. Arabisch, Kyrillisch, Chinesisch) in Fließtext, Überschriften, Kommentaren oder Beispielen.
  - Wenn ein externes Zitat/Begriff zwingend ist: **als Zitat markieren** und kurz auf Deutsch/Englisch erklären.
- Konsistente Begriffe:
  - “Investment” (Investor → Trader Pool)
  - “Order” (Order Placement)
  - “Trade” (Position/Trade Lifecycle)
  - “WalletTransaction” (Buchung)
  - “Legal Document” (AGB/Datenschutz/Impressum)
- Fachjargon nur wo nötig; ansonsten erklären.

## 5) Doc Hygiene (Anti-Drift)

### Source-of-Truth Reminder

Wenn Unsicherheit besteht, verlinke auf die maßgeblichen Stellen:

- iOS DI/Architektur: `FIN1/FIN1App.swift`, `FIN1/Shared/Services/AppServices.swift`, `.cursor/rules/architecture.md`
- Backend API/Cloud Code: `backend/parse-server/index.js`, `backend/parse-server/cloud/**`
- Environments: `Config/*.xcconfig`, `Info.plist`, `backend/env.production.example`

### Regelmäßige Review-Cadence (Empfehlung)

- Monatlich: NFRs/Runbook/Release Prozess prüfen
- Pro Release: Requirements/Legal/Audit prüfen
- Nach Incidents: Doku + Guardrails aktualisieren

## 6) Dokument-Index aktualisieren

Wenn neue “offizielle” Dokumente entstehen, müssen sie im Root-Index verlinkt werden:

- `Documentation/README.md`

