---
title: "FIN1 App-Dokumentation – Index"
audience: ["Stakeholder", "Produkt", "Entwicklung", "QA", "Betrieb", "Support", "Compliance"]
lastUpdated: "2026-02-01"
---

## Zweck

Diese Dokumentation beschreibt **FIN1** als Investment-/Trading-Plattform (iOS App + Backend). Sie ist so aufgebaut, dass unterschiedliche Zielgruppen schnell die relevanten Informationen finden.

## Aktueller Scope (Reality Check)

- **iOS App**: SwiftUI (iOS 16+), MVVM + DI über `AppServices` (`FIN1/FIN1App.swift`).
- **Backend**: Parse Server (Node.js/Express) hinter Nginx + MongoDB + Redis + optionale Services (Market Data, Notifications, Analytics, PDF, MinIO, Postgres).
- **Android App**: **nicht im Repository enthalten** (keine Gradle/Manifest-Struktur gefunden). Backend ist jedoch für Android Push (FCM) vorbereitet.

## Source of Truth (wichtig, da nicht alle Docs aktuell sind)

Wenn Dokumente und Code/Configs widersprechen, gilt:

1. **Code & Build-Konfiguration** (z.B. `FIN1/`, `Config/*.xcconfig`, `Info.plist`) sind maßgeblich.
2. **Backend-Konfiguration & Cloud Code** (z.B. `backend/parse-server/index.js`, `backend/parse-server/cloud/**`) sind maßgeblich.
3. **Dokumentation** ergänzt und erklärt – darf aber nie “gegen” Code/Config behaupten.

## Dokumentationsstruktur (8 Hauptbereiche)

1. **Übergeordnete Projektdokumentation (Stakeholder/Management)**
   Siehe [`01_PROJEKTUEBERBLICK.md`](01_PROJEKTUEBERBLICK.md)
2. **Fachliche Spezifikation / Requirements (Produkt/BA/QA)**
   Siehe [`02_REQUIREMENTS.md`](02_REQUIREMENTS.md)
   - Feature-Schutz (Guardrails): [`02A_FEATURE_KATALOG_GUARDRAILS.md`](02A_FEATURE_KATALOG_GUARDRAILS.md)
3. **Technische Spezifikation (Architektur/Backend/API/Datenmodell/Security)**
   Siehe [`03_TECHNISCHE_SPEZIFIKATION.md`](03_TECHNISCHE_SPEZIFIKATION.md)
4. **Entwicklernähere Dokumentation (Setup/Guides/Build & Deployment)**
   Siehe [`04_DEVELOPER_GUIDE.md`](04_DEVELOPER_GUIDE.md)
5. **Test- und Qualitätsdokumentation (QA/Dev)**
   Siehe [`05_TEST_QUALITAET.md`](05_TEST_QUALITAET.md)
6. **Betriebs- und Prozessdokumentation (Ops/SRE/Release Mgmt)**
   Siehe [`06_BETRIEB_PROZESSE.md`](06_BETRIEB_PROZESSE.md)
   - Ubuntu Backend Runbook: [`06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md`](06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md)
   - Enthält: Hardening-Stufenplan (Ports/Firewall/OS-Services)
   - CSR Support Workflow & Aufgabenverteilung: [`06B_CSR_SUPPORT_WORKFLOW.md`](06B_CSR_SUPPORT_WORKFLOW.md)
7. **User-Dokumentation (Endnutzer/Admins)**
   Siehe [`07_USER_GUIDE.md`](07_USER_GUIDE.md)
8. **Struktur, Form und Pflege (Doc Governance)**
   Siehe [`08_PFLEGE_VERSIONING.md`](08_PFLEGE_VERSIONING.md)

## Schnelleinstieg nach Zielgruppe

- **Stakeholder**: `01_PROJEKTUEBERBLICK.md` → Vision, Ziele, Erfolgskriterien, Systemlandschaft.
- **Produkt/BA**: `02_REQUIREMENTS.md` → Stories, Regeln, NFRs, Schnittstellen zu Fachbereichen.
- **Entwicklung (iOS/Backend)**: `03_TECHNISCHE_SPEZIFIKATION.md` + `04_DEVELOPER_GUIDE.md`.
- **QA**: `05_TEST_QUALITAET.md` → Teststrategie, Szenarien, Acceptance-Criteria-Checklisten.
- **Betrieb/Ops**: `06_BETRIEB_PROZESSE.md` → Runbook, Backup/Restore, Monitoring, Release/Rollback.
- **Support/CSR**: `02_REQUIREMENTS.md` (Support-Prozesse) + `07_USER_GUIDE.md` (User-Fragen/FAQ).

