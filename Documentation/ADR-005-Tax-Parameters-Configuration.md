# ADR-005: Tax Parameters as Managed Configuration

## Status
Accepted

## Context
FIN1 currently has dynamic financial parameters (for example `appServiceChargeRate`) but tax-related values in legal/FAQ content were partially hardcoded (for example `25 %`, `19 %`).

This creates three risks:

1. Inconsistent values across FAQ, AGB/Rechtstexte, and generated documents.
2. Manual content edits for legal/tax updates.
3. Increased compliance risk due to missing single source of truth.

The project already has:

- Config infrastructure (`Configuration`, `loadConfig`, cache, 4-eyes workflows).
- Placeholder hydration in `getFAQs` and now `getCurrentTerms`.

## Decision
Introduce a dedicated `tax` section in backend configuration, separate from `financial`.

Initial model:

```json
{
  "tax": {
    "withholdingTaxRate": 0.25,
    "solidaritySurchargeRate": 0.055,
    "vatRate": 0.19,
    "taxCollectionMode": "customer_self_reports"
  }
}
```

Rules:

- `tax` is compliance-critical and must use 4-eyes approval.
- Changes must be auditable with reason and approver metadata.
- Legal/FAQ placeholders resolve from config values, not hardcoded literals.
- `taxCollectionMode` is a single governance switch for withholding handling
  (`platform_withholds` vs `customer_self_reports`).
- Church tax is not admin-configurable as a rate: it is derived from user profile
  (religion + German state), with fallback to `0` if required data is missing.

## Consequences

### Positive

- One source of truth for tax rates.
- Placeholder-driven legal/faq content remains stable while values evolve.
- Reduced operational errors during updates.

### Trade-offs

- Additional configuration governance and validation required.
- Admin UI must clearly separate tax from operational fee settings.
- Role permissions for tax changes must be stricter than for normal financial changes.

## Implementation Notes (Incremental)

1. Backend foundation (done):
   - Add `tax` defaults in `defaultConfig`.
   - Resolve `tax` in `loadConfig` (nested + flat fallback).
   - Use `tax` values in `getCurrentTerms` hydration (`TAX_RATE`, `VAT_RATE`).

2. Workflow hardening (next):
   - Add `tax.*` fields to config validation.
   - Mark tax parameters as critical in 4-eyes.
   - Add server-side bounds validation.

3. Admin Portal (next):
   - New "Steuerparameter" card under configuration.
   - Explain legal impact and effective-date expectation.

4. iOS / Content:
   - Keep legal/faq content tokenized (`{{TAX_RATE}}`, `{{VAT_RATE}}`).
   - Avoid hardcoded percentages in policy text.

5. Settlement / Accounting (done):
   - Apply `taxCollectionMode` in backend settlement for investor and trader payouts.
   - If mode is `platform_withholds`, post withholding-tax debits:
     `withholding_tax_debit`, `solidarity_surcharge_debit`, optional `church_tax_debit`.
   - If mode is `customer_self_reports`, no tax debit postings are created.

6. Guardrails & Parity hardening (done):
   - Server-side enum normalization for `taxCollectionMode` in:
     - `cloud/utils/configHelper/loadConfig.js`
     - `cloud/functions/configuration/shared.js`
   - Invalid mode values fail-safe to `customer_self_reports`.
   - `applyConfigurationChange` audit log now reports the applied (normalized) value.
   - Admin-Portal `resolveConfig` defaults include string defaults in empty-payload path.
   - Admin-Portal disables `taxCollectionMode` dropdown while a pending 4-eyes request exists.

## Operational Invariants (added 2026-04-15)

- Persisted value in `Configuration.tax.taxCollectionMode` is authoritative over UI defaults.
- Defaults are fallback-only and must never overwrite existing active config.
- Legal/FAQ/document hydration and settlement behavior must derive from normalized config values.

## Notes on Formatting

- `TAX_RATE` is delivered as effective total percent including solidarity surcharge (`withholdingTaxRate + withholdingTaxRate * solidaritySurchargeRate`).
- `VAT_RATE` is delivered as configured VAT percent.

## Related

- [`ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md`](ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md) — **Settlement-/Konsistenz**-Smoke, Admin-Portal-**System-Health** und App-Ledger-QA ergänzen die rein steuerliche Konfiguration (ADR-005) operativ.

