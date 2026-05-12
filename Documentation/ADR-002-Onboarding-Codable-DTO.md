# ADR-002: Onboarding payloads — Codable DTOs and Parse contracts

## Status
**ACCEPTED** — Effective immediately

## Context
- Multi-step onboarding persists progress via Parse Cloud Functions (`savePartialProgress`, `completeOnboardingStep`, etc.).
- Untyped `[String: Any]` snapshots are easy to drift from server validation and hard to refactor safely.
- Compliance and audit live on the server (`sanitizeObject`, `validateStepData`, `OnboardingAudit`); the client must not be treated as the source of truth for rules.

## Decision

### 1. Client: `Codable` structs for saved onboarding data
- Define a **single Codable struct** (e.g. `SavedOnboardingData` in `OnboardingAPIService.swift`) for the blob stored under `savedData` / returned progress.
- **Build** snapshots from feature models (e.g. `SignUpData.savedOnboardingData()`), not from ad-hoc dictionaries in Views.
- **Encode** to JSON-compatible `[String: Any]` **only inside** `*APIService` when calling `ParseAPIClientProtocol.callFunction`. Views and ViewModels do not assemble raw payload dictionaries for these flows.

### 2. MVVM boundaries
- Coordinators / ViewModels orchestrate steps and state.
- **`*APIService`** owns the wire contract to Parse.
- No Parse SDK types in Views (see `.cursor/rules/architecture.md`).

### 3. Backend remains authoritative
- Server-side validation, sanitization, and audit **must** run for every path that mutates onboarding state.
- Client DTOs improve **type safety and maintainability**; they do **not** replace server validation.

### 4. Contract alignment
- JSON keys from Swift encoding must match what the Cloud Functions expect, in particular:
  - `backend/parse-server/cloud/functions/user/onboarding.js`
  - `backend/parse-server/cloud/utils/validation.js`
- New required fields for a step require **coordinated** Swift + Node updates.

### 5. Partial save vs completion
- **“Save for later”**: update **`currentStep` + `savedData`** only.
- **`completedSteps`** (and phase completion flags): append **only** after a successful **`completeOnboardingStep`** (or equivalent Cloud Function), not on partial save.

### 6. Per-step schema validation (Joi)
- **Implemented**: [`backend/parse-server/cloud/utils/onboardingStepSchemas.js`](../backend/parse-server/cloud/utils/onboardingStepSchemas.js) defines Joi schemas aligned with the former manual rules.
- `validateStepData` (complete step) and `validatePartialOnboardingData` (partial save) are wired from [`validation.js`](../backend/parse-server/cloud/utils/validation.js) and used by [`onboarding.js`](../backend/parse-server/cloud/functions/user/onboarding.js) (`completeOnboardingStep`, `saveOnboardingProgress`).
- Optional future work: JSON Schema docs in `Documentation/` or stricter consents rules if product requires “must be true” on every complete.

## Rationale
- **Codable** gives compile-time structure, easier refactors, and optional fields for backward-compatible decoding of older saved JSON.
- **Encoding only in APIService** keeps a single choke point for keys and reduces duplication.
- **Separating partial save from completion** keeps resume semantics and audit trails clear.

## Consequences
- **Positive**: Safer refactors, clearer ownership of the wire format, smaller partial payloads when completion lists are not touched.
- **Negative**: Any payload change needs a quick check of Node validation and possibly migration notes; optional server schemas add maintenance.

## References
- Section **“Onboarding and multi-step flows”** in [`Documentation/ENGINEERING_GUIDE.md`](ENGINEERING_GUIDE.md) (Joi implementation note)
- Cursor rules: `.cursor/rules/architecture.md`, `.cursor/rules/documentation-checkpoints.md`
- Related ADR: [`ADR-001-Navigation-Strategy.md`](ADR-001-Navigation-Strategy.md)
- [`ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md`](ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md) — ergänzend: **Parse-Feld-Merge** auf iOS und **Betriebs-QA**, sobald Investment-/Trade-Daten aus dem Backend synchronisiert werden (nicht Onboarding-spezifisch, aber gleiche SSOT-Disziplin)
