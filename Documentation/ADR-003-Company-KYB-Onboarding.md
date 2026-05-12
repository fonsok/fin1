# ADR-003: Company KYB (juristische Person) – getrennt vom Personal-KYC

## Status
**ACCEPTED** – Schrittliste und Routing-Regeln in [`COMPANY_KYB_ONBOARDING.md`](COMPANY_KYB_ONBOARDING.md) festgelegt; technische Umsetzung folgt Phasen P1–P3.

## Context
- Es gibt ein etabliertes **Personal-Onboarding** (KYC) mit Parse Cloud Functions und Joi-Validierung.
- **Firmenkonten** (`accountType: company`) erhalten ein **eigenes KYB** (eigene Felder, eigene Functions, eigener Audit-Pfad).
- **Investor-only** für Firmen; **kein** paralleles Bearbeiten von Personal-KYC und Company-KYB.

## Decision
1. **Eigene** User-Felder und APIs für Company-KYB (siehe `COMPANY_KYB_ONBOARDING.md`).
2. **Keine** Vermischung mit `onboardingStep` / `onboardingCompleted` für Firmendaten.
3. **Codable** auf iOS, **Joi** auf dem Server; gleiche Disziplin wie ADR-002.
4. **Acht KYB-Schritte** (Reihenfolge fix): `legal_entity` → `registered_address` → `tax_compliance` → `beneficial_owners` → `authorized_representatives` → `documents` → `declarations` → `submission`.
5. **Resume:** Company-KYB hat **Vorrang** vor Personal-Onboarding, wenn `accountType == company` und KYB noch nicht abgeschlossen.

## Consequences
- Implementierung kann an fixe `validSteps`-Liste und Joi-Schemas anbinden.
- Legal/Compliance sollte Stichproben zu Pflichtfeldern und Dokumentalter dokumentieren (Policy-Parameter).

## References
- [`Documentation/COMPANY_KYB_ONBOARDING.md`](COMPANY_KYB_ONBOARDING.md)
- [`Documentation/ADR-002-Onboarding-Codable-DTO.md`](ADR-002-Onboarding-Codable-DTO.md)
- [`Documentation/ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md`](ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md) — orthogonal zu KYB: **Admin-System-Health**, Finance-Smoke, App-Ledger (Ops)
