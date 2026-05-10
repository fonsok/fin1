---
title: "FIN1 App-Dokumentation – Index"
audience: ["Stakeholder", "Produkt", "Entwicklung", "QA", "Betrieb", "Support", "Compliance"]
lastUpdated: "2026-05-02"
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

**Lab-Host / URLs (canonical):** [`CANONICAL_HOST_AND_URLS.md`](../CANONICAL_HOST_AND_URLS.md) (`fin1-lab.example`, `/etc/hosts`, CI `FIN1_LAB_HOST`). **PHASE-/snapshotartige Markdown** ohne Pflege: Git-Historie verbindlich; für Leser klar als Kontext/Archiv einordnen oder nach `Documentation/Archive/` verschieben (siehe Root-[`Documentation/README.md`](../README.md)).

## Dokumentationsstruktur (8 Hauptbereiche)

1. **Übergeordnete Projektdokumentation (Stakeholder/Management)**
   Siehe [`01_PROJEKTUEBERBLICK.md`](01_PROJEKTUEBERBLICK.md)
2. **Fachliche Spezifikation / Requirements (Produkt/BA/QA)**
   Siehe [`02_REQUIREMENTS.md`](02_REQUIREMENTS.md)
   - Feature-Schutz (Guardrails): [`02A_FEATURE_KATALOG_GUARDRAILS.md`](02A_FEATURE_KATALOG_GUARDRAILS.md)
3. **Technische Spezifikation (Architektur/Backend/API/Datenmodell/Security)**
   Siehe [`03_TECHNISCHE_SPEZIFIKATION.md`](03_TECHNISCHE_SPEZIFIKATION.md) — **canonical** für iOS-Client ↔ Backend (Schichten, Parse REST/Live Query, **Swift 6 / Sendable / Parse-DTO** unter Abschnitt 1).
   - Belege, Rechnungen, Emittent/Handelsplatz: Abschnitt 6 in 03
   - Onboarding (Cloud Functions + Joi-Validierung): Abschnitt 3.2 „User/FAQ“ und 3.3 in 03; ADR: [`../ADR-002-Onboarding-Codable-DTO.md`](../ADR-002-Onboarding-Codable-DTO.md)
   - **Company / KYB (Firmen-Onboarding, implementiert):** [`../COMPANY_KYB_ONBOARDING.md`](../COMPANY_KYB_ONBOARDING.md), ADR: [`../ADR-003-Company-KYB-Onboarding.md`](../ADR-003-Company-KYB-Onboarding.md)
4. **Entwicklernähere Dokumentation (Setup/Guides/Build & Deployment)**
   Siehe [`04_DEVELOPER_GUIDE.md`](04_DEVELOPER_GUIDE.md)
5. **Test- und Qualitätsdokumentation (QA/Dev)**
   Siehe [`05_TEST_QUALITAET.md`](05_TEST_QUALITAET.md)
6. **Betriebs- und Prozessdokumentation (Ops/SRE/Release Mgmt)**
   Siehe [`06_BETRIEB_PROZESSE.md`](06_BETRIEB_PROZESSE.md)
  - Ubuntu Backend Runbook: [`06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md`](06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md)
  - Return%-Monitoring/Alerting: [`../RETURN_PERCENTAGE_MONITORING_AND_ALERTING.md`](../RETURN_PERCENTAGE_MONITORING_AND_ALERTING.md)
  - Return%-Incident SOP: [`../RETURN_PERCENTAGE_INCIDENT_SOP.md`](../RETURN_PERCENTAGE_INCIDENT_SOP.md)
  - Return%-Release Verification: [`../RELEASE_VERIFICATION_RETURN_PERCENTAGE_CONTRACT_2026-04-20.md`](../RELEASE_VERIFICATION_RETURN_PERCENTAGE_CONTRACT_2026-04-20.md)
   - Parse Cloud: keine Legacy-Datei `cloud/utils/configHelper.js` (Shadowing, Admin-Konfig-Fehler) → Runbook **§ 8.2.1**, Kurzüberblick in `06_BETRIEB_PROZESSE.md`
   - Deployment / rsync (kein `--delete` auf Server-Backend): [`../DEPLOYMENT_RSYNC_SICHERHEIT.md`](../DEPLOYMENT_RSYNC_SICHERHEIT.md)
   - Moderne Deploy-Reife (CI-Artefakte, Images, Rollback): [`../MODERN_DEPLOY_BEST_PRACTICES.md`](../MODERN_DEPLOY_BEST_PRACTICES.md) — CI: `.github/workflows/deploy-manifest-artifact.yml`, `.github/workflows/parse-server-docker-build.yml`
  - Deploy-Host-Klarheit (iobox `.24`/`.20`, Skripte, `scripts/.env.server`): [`../OPERATIONAL_DEPLOY_HOSTS.md`](../OPERATIONAL_DEPLOY_HOSTS.md)
   - Enthält: Hardening-Stufenplan (Ports/Firewall/OS-Services)
   - CSR Support Workflow & Aufgabenverteilung: [`06B_CSR_SUPPORT_WORKFLOW.md`](06B_CSR_SUPPORT_WORKFLOW.md)
7. **User-Dokumentation (Endnutzer/Admins)**
   Siehe [`07_USER_GUIDE.md`](07_USER_GUIDE.md)
8. **Struktur, Form und Pflege (Doc Governance)**
   Siehe [`08_PFLEGE_VERSIONING.md`](08_PFLEGE_VERSIONING.md)
9. **Admin-Rollen und Aufgabentrennung (Separation of Duties)**
   Siehe [`09_ADMIN_ROLES_SEPARATION.md`](09_ADMIN_ROLES_SEPARATION.md)
   - RACI-Matrix für Xcode-Admin vs. Server-Admin
   - App-Level Rollen (admin, business_admin, security_officer, compliance, customer_service)
   - Security Hardening Checkliste
   - Firewall-Setup: [`09A_SERVER_FIREWALL_SETUP.md`](09A_SERVER_FIREWALL_SETUP.md)
10. **Admin-Web-Portal (Browser-Zugang für App-Admins)**
    Siehe [`10_ADMIN_PORTAL_REQUIREMENTS.md`](10_ADMIN_PORTAL_REQUIREMENTS.md)
    - **Stand 2026-04-15:** Steuerparameter-Hardening: `Umsatzsteuer` oberhalb `Abgeltungsteuer` (Dropdown), Detailsteuern nur bei `platform_withholds`, Dropdown-Sperre bei pending 4-Augen-Request; serverseitige Tax-Mode-Guardrails/Normalisierung in `03_TECHNISCHE_SPEZIFIKATION.md` dokumentiert
    - **Stand 2026-04-15:** Legal Branding (`{{APP_NAME}}`) kanonisch unter **Konfiguration → Systemparameter** (`legalAppName`, 4‑Augen); AGB & Rechtstexte nur Hinweis/Deep‑Link; `updateLegalBranding` deprecated/blockiert
    - **Stand 2026-04:** Hilfe & Anleitung: **FAQ-Import (Restore)** mit Dry-Run, **Development Maintenance** (`devResetFAQsBaseline`) und ENV `ALLOW_FAQ_HARD_DELETE*` (siehe [`06_BETRIEB_PROZESSE.md`](06_BETRIEB_PROZESSE.md), Runbook § 8.4)
    - **Stand 2026-03:** CSR-Web **KYB-Status** (Firmen, Leserecht), Admin-Navigation **KYB-Status**, Vitest-Helfer, ESLint 9 + CI-Job `admin-portal`
    - Server-driven **Hilfe & Anleitung** (FAQs): technischer Tiefgang, Cloud-Code-Deployment, Paging → [`../HELP_N_INSTRUCTIONS_SERVER_DRIVEN.md`](../HELP_N_INSTRUCTIONS_SERVER_DRIVEN.md)
    - Anforderungen pro Rolle
    - Screen-Übersicht
    - Technologie-Empfehlung
11. **App Ledger – Handbuch für Buchhalter**
    Siehe [`11_APP_LEDGER_BUCHHALTER_MANUAL.md`](11_APP_LEDGER_BUCHHALTER_MANUAL.md)
    - Kontenrahmen, Buchungslogik, Bank Clearing ↔ Erlös ↔ USt
    - Nutzung Admin-Portal (Filter, Export), Prüfungen, Glossar
    - Verbindliche Escrow-Status-Policy inkl. Hinweis: Bei Löschung/Storno im Status `reserved` erfolgt die Rückbuchung ins Nutzerkonto; sichtbar in Cash Balance und Account Statement/Kontoauszug
    - **Reservierte Investments / Escrow (Zielbild, technisch Architektur):** [`../INVESTMENT_ESCROW_LEDGER_SKETCH.md`](../INVESTMENT_ESCROW_LEDGER_SKETCH.md)
   - **Teil-Sell-Kennzahlen (iOS), Finance-Smoke, System-Health, App-Ledger-Totals:** [`../ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md`](../ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md)
12. **Produktmerkmale für KI & FAQ**
    Siehe [`12_PRODUKT_MERKMALE_KI_FAQ.md`](12_PRODUKT_MERKMALE_KI_FAQ.md)
    - Merkmale mit hohem KI-Verständnis, FAQ-taugliche Themen, einheitliche Begriffe
    - **Abschnitt 6:** AI-Einordnung (Positionierung für KI-Suche) – EN/DE Einzeiler für Metadaten, App-Store, RAG
    - **Abschnitt 7:** Landing-Page & App-Store-Optimierung für KI-Suche (sichtbarer Text, Accessibility, FAQ, Store-Texte)
13. **Portfolio-Begriff ersetzt**
    Siehe [`13_PORTFOLIO_BEGRIFF_ERSETZUNG.md`](13_PORTFOLIO_BEGRIFF_ERSETZUNG.md)
    - Ersetzungsmatrix, empfohlene Begriffe (Investments/Depot), betroffene Stellen

## Schnelleinstieg nach Zielgruppe

- **Stakeholder**: `01_PROJEKTUEBERBLICK.md` → Vision, Ziele, Erfolgskriterien, Systemlandschaft.
- **Produkt/BA**: `02_REQUIREMENTS.md` → Stories, Regeln, NFRs, Schnittstellen zu Fachbereichen.
- **Entwicklung (iOS/Backend)**: `03_TECHNISCHE_SPEZIFIKATION.md` + `04_DEVELOPER_GUIDE.md`.
- **QA**: `05_TEST_QUALITAET.md` → Teststrategie, Szenarien, Acceptance-Criteria-Checklisten.
- **Betrieb/Ops**: `06_BETRIEB_PROZESSE.md` → Runbook, Backup/Restore, Monitoring, Release/Rollback.
  - Für Return%-Contract speziell: täglicher Monitor + reboot catch-up, wöchentliche Reconciliation, auth-basierter Smoke-Test, DB-Validator.
- **Support/CSR**: `02_REQUIREMENTS.md` (Support-Prozesse) + `07_USER_GUIDE.md` (User-Fragen/FAQ) + `12_PRODUKT_MERKMALE_KI_FAQ.md` (FAQ-taugliche Merkmale/Begriffe).
- **Buchhaltung/Controlling**: `11_APP_LEDGER_BUCHHALTER_MANUAL.md` → App Ledger, Konten, Abläufe, Admin-Portal-Nutzung.

