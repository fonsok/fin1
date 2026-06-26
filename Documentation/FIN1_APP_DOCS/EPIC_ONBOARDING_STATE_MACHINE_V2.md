---
title: "Epic — Onboarding State Machine v2"
audience: ["Produkt", "Entwicklung", "QA", "Architektur"]
lastUpdated: "2026-06-23"
epicId: "FIN1-ONB-v2"
---

# Epic: Onboarding State Machine v2

**PDF (Diagramme + Tabellen):** [`EPIC_ONBOARDING_STATE_MACHINE_V2.pdf`](EPIC_ONBOARDING_STATE_MACHINE_V2.pdf)  
**PDF neu erzeugen:** `node Documentation/diagrams/onboarding-epic-v2/build-epic-pdf.mjs` (nach `npm install` in `Documentation/diagrams/`)

## Ziel

Ein einziger, testbarer Onboarding-Zustand als **Single Source of Truth** — von Step-Navigation bis Dashboard-Gate — ohne verteilte Flags, Notifications und Race-Conditions.

| | |
|---|---|
| **Zeithorizont** | 1,5–2,5 Wochen (1 Dev, fokussiert) · 3–4 Wochen neben Features |
| **Story Points** | ~49 |
| **Nicht-Ziel** | UI-Redesign der 24 Steps · KYB-Wizard · Post-Onboarding Re-Consent (eigenes Epic) |

---

## 1. Ausgangslage (Ist)

### Verteilter State

Siehe **Diagramm 1** im PDF: Ist-Architektur mit `SignUpData`, `SignUpCoordinator` (+ 11 Extensions), `SignUpFlowSession`, `UserService`, `UserSessionObserver`, `AuthenticationView` und Parse Cloud (`OnboardingProgress`, `completeOnboardingStep`, …).

### Schmerzpunkte

| Komponente | Rolle heute | Problem |
|------------|-------------|---------|
| `SignUpData` (~400+ Zeilen, 4 Extensions) | Formular-State + Validierung + Export | Vermischt UI-State, Domain, API-DTO |
| `SignUpCoordinator` (11 Dateien) | Navigation, Persistenz, Finalize, Telemetry | God-Object, schwer unit-testbar |
| `SignUpFlowSession` | Global static: Landing/Dismiss/Resume | Nicht serialisierbar, nicht server-synced |
| `User.onboardingCompleted` | Dashboard-Gate | Wird lokal/server unterschiedlich gesetzt |
| `UserSessionObserver` | UI-Reaktion | Workaround für fehlende SSOT |
| `NotificationCenter` | Cross-View Events | Implizite Kopplung |
| Backend | 3 APIs + Audit | UI-Steps (24) ≠ Backend-Steps (7) — Mapping fragil |

### Bekannte Incidents (2026-06)

- Blauer Screen nach Registrierung (Client/Server `onboardingCompleted` divergiert)
- Scroll-to-Accept durch nested ScrollViews umgangen
- `Insufficient auth` beim Profil-Sync (falsche User-Identity / REST auf `_User`)
- Redundante Finalize-Calls (teilweise durch gezielte Härtung behoben)

**Relevante Pfade (Ist):**

- `FIN1/Features/Authentication/Views/SignUp/` — Coordinator, 24 Steps, `SignUpFlowSession`
- `FIN1/Features/Authentication/Views/AuthenticationView.swift` — Dashboard-Gate
- `backend/parse-server/cloud/functions/user/onboarding.js` — `save/complete/getOnboardingProgress`

---

## 2. Soll-Architektur

### State Machine

Siehe **Diagramm 2** im PDF: `idle` → `accountSetup` → `authenticated` → `inProgress` → `roleAgreement` → `finalizing` → `completed` → MainTabView.

### Schichten

| Schicht | Verantwortung |
|---------|---------------|
| **`OnboardingSession`** (neu) | Enum-State + `SavedOnboardingData` + aktueller `SignUpStep` |
| **`OnboardingEngine`** (neu) | State transitions, Validierung, Server-Commands |
| **`OnboardingAPIService`** (bestehend, erweitert) | `get/save/complete` — einzige Server-Schnittstelle |
| **Step Views** (bestehend) | Nur UI + Bindings an Session-Slice |
| **`AuthenticationRouter`** (ersetzt Gate in `AuthenticationView`) | `session.phase == .completed` → Dashboard |

### Geplante Modulstruktur (iOS)

```
FIN1/Features/Authentication/Onboarding/
  OnboardingSession.swift
  OnboardingEngine.swift
  OnboardingEngine+Persistence.swift
  OnboardingEngine+Finalize.swift
  OnboardingStepRegistry.swift
```

### Server als SoT

| Phase | Server schreibt | Client darf lokal setzen |
|-------|-----------------|--------------------------|
| In Progress | `OnboardingProgress.data`, `onboardingStep` | Nur optimistisch, bis `save` bestätigt |
| Phase complete | `OnboardingAudit`, `_User.onboardingStep` | — |
| Role agreement | `LegalConsent`, `acceptedTrader/InvestorAgreement*` | Nach `recordRoleAgreementConsent` success |
| Completed | `_User.onboardingCompleted = true` | Nur nach Server-Bestätigung oder `getUserMe` |

**Regel:** Nach `completed` gewinnt immer der Server. Während `inProgress` gewinnt der Server bei Konflikt.

---

## 3. Phasenplan

| Phase | Dauer | Deliverables |
|-------|-------|--------------|
| **0 — Vorbereitung** | 2–3 Tage | State-Diagramm + Transition-Tabelle (24 UI → 4 Phasen → 7 Backend); Contract `onboardingSessionStates.json`; Feature-Flag; Baseline-Telemetrie |
| **1 — Domain Layer** | 3–4 Tage | `OnboardingSession`, `OnboardingEngine`, Unit-Tests Trader/Investor/RC7/Role Agreement |
| **2 — Server-Sync** | 2–3 Tage | `getOnboardingSession` (1 Round-Trip); `finalize()` als Pipeline; Integration-Tests |
| **3 — UI-Migration** | 3–5 Tage | Strangler: Coordinator → Engine; `AuthenticationRouter`; `LegalDocumentGate`; UI-Tests |
| **4 — Aufräumen** | 2–3 Tage | Legacy entfernen; Flag default on; Docs |

### Phase 0 — Checkliste

- [ ] Transition-Tabelle: alle `SignUpStep` → `OnboardingPhase` → Backend-Step
- [ ] Contract: `shared/contracts/onboardingSessionStates.json`
- [ ] Feature-Flag: `onboardingStateMachineV2`
- [ ] Baseline: Drop-off pro Step, `onboarding_completed`, Time-to-Dashboard

### Phase 3 — Strangler-Reihenfolge

1. `SignUpView` liest `engine.session.currentStep`
2. `AuthenticationRouter` ersetzt Dashboard-Gate
3. `SignUpFlowSession` → `session.presentationContext`
4. Notifications → ein Event: `onboardingSessionDidChange`

---

## 4. Erfolgskriterien (Definition of Done)

| Kriterium | Messung |
|-----------|---------|
| Kein blauer Placeholder nach Signup | 0 reproduzierbare Fälle in 2 Wochen QA |
| Single API resume | max. 1 Call beim App-Start (`getOnboardingSession`) |
| Testabdeckung Engine | ≥ 90 % Transitions unit-tested |
| Finalize Netzwerk | ≤ 3 sequenzielle Server-Calls |
| Legal Gate | Scroll-to-Accept UI-Test grün (Role Agreement) |
| Telemetry | `onboarding_step_completed` aus Engine |
| Kein `SignUpFlowSession` | Grep = 0 Treffer |

---

## 5. Risiken & Mitigation

| Risiko | Impact | Mitigation |
|--------|--------|------------|
| 24 Steps brechen bei Migration | Hoch | Strangler + Feature-Flag; Step-Views unverändert |
| Server/Client Step-Mismatch | Hoch | Contract-JSON + CI-Test gegen `SignUpStep.backendKey` |
| Regression Investor vs. Trader | Mittel | Parametrisierte Tests pro Role |
| Verschlüsselte `OnboardingProgress` | Mittel | Früh mit echtem Server testen |
| Zeitdruck andere Features | Hoch | Phase 0–1 parallel; UI später |

---

## 6. Bewusst nicht im Epic

- Company KYB Wizard
- Post-Onboarding Re-Consent Modal
- Redesign Risk-Class-UI
- Migration historischer `OnboardingProgress`-Daten (nur Forward-Compatibility)
- Backend-Wechsel weg von Parse

---

## 7. Go / No-Go

### Go (mind. 2 erfüllt)

- [x] Re-Consent nach Vertragsupdate geplant (< 6 Monate) — **umgesetzt** ([`EPIC_POST_ONBOARDING_RE_CONSENT.md`](EPIC_POST_ONBOARDING_RE_CONSENT.md), Staging Go 2026-06)
- [ ] Multi-Device Resume ist Product-Anforderung
- [ ] Zweiter schwerer Onboarding-Bug nach aktuellen Fixes
- [ ] Dediziertes Sprint-Budget (≥ 10 Dev-Tage)

### No-Go

- Nur „Code schöner machen“
- Kein QA-Budget für Full-Signup-Regression
- Paralleles großes Trading/KYB-Release ohne Freeze-Fenster

---

## 8. Backlog-Schnitt

| # | Story | Points | Phase |
|---|-------|--------|-------|
| 1 | OnboardingSession enum + Transition-Tabelle | 3 | 0–1 |
| 2 | OnboardingEngine unit tests (Trader path) | 5 | 1 |
| 3 | OnboardingEngine unit tests (Investor path) | 3 | 1 |
| 4 | getOnboardingSession Cloud Function | 5 | 2 |
| 5 | Engine.resume() + save/complete integration | 5 | 2 |
| 6 | SignUpView → Engine delegation (Feature-Flag) | 8 | 3 |
| 7 | AuthenticationRouter + Dashboard gate | 5 | 3 |
| 8 | LegalDocumentGate (Scroll-to-Accept unified) | 3 | 3 |
| 9 | UI-Test Happy Path Trader | 5 | 3 |
| 10 | Remove SignUpCoordinator / FlowSession | 5 | 4 |
| 11 | Docs + Flag default on | 2 | 4 |

---

## 9. Empfehlung

**Jetzt:** Epic im Backlog; **Phase 0** (Mapping + Contract) als Spike (1–2 Tage) ohne Production-UI-Änderung.

**Start Phase 1–4:** Bei Re-Consent, Multi-Device Resume oder zweitem Production-Bug.

Die **gezielte Härtung** (2026-06) bleibt gültig und ist die Brücke bis v2 — nicht obsolet.

---

## Verwandte Dokumentation

- Onboarding Backend: [`03_TECHNISCHE_SPEZIFIKATION.md`](03_TECHNISCHE_SPEZIFIKATION.md) Abschnitt Onboarding
- ADR DTO: [`../ADR-002-Onboarding-Codable-DTO.md`](../ADR-002-Onboarding-Codable-DTO.md)
- Signup-Flow-Diagramme: [`../diagrams/rc5-signup-flow.pdf`](../diagrams/rc5-signup-flow.pdf)
- Compliance Role Agreement: `.cursor/rules/compliance.md`
