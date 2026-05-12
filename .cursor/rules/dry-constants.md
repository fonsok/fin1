---
alwaysApply: true
---

# DRY (Don't Repeat Yourself) & Constants

## Core Principles

- **MANDATORY**: All magic numbers, percentages, rates, and repeated string values must be defined as constants.
- **FORBIDDEN**: Hardcoded numeric values (percentages, rates, fees, limits) in multiple places.
- **REQUIRED**: Use `CalculationConstants` in `FIN1/Shared/Models/CalculationConstants.swift` for all financial calculations.
- **REQUIRED**: Define both calculation values (Double) and display strings (String) for percentages/rates.
- **FORBIDDEN**: Duplicating the same percentage/rate value in multiple files (e.g., `0.02`, `2%`).

## Admin-Configurable vs Fixed Constants

Some financial rates are **admin-configurable** at runtime via `ConfigurationService` (backed by the Parse Server `Configuration` class). These have a different lifecycle than fixed constants.

### Fee responsibility by role (product model)

- **Investors** pay **app service charge** (on investments). They do **not** pay order fee, exchange fee, or the other trading-fee constants in `CalculationConstants.FeeRates`.
- **Traders** pay **order fee, exchange fee**, and related trading fees. They do **not** pay app service charge.

This split must stay consistent when adding new fees or wiring `ConfigurationService` / backend defaults.

### Admin-Configurable Rates

| Rate | ConfigurationService property | CalculationConstants fallback |
|------|-------------------------------|-------------------------------|
| Trader commission | `traderCommissionRate` / `effectiveCommissionRate` | `FeeRates.traderCommissionRate` (0.10) |
| App service charge (investors) | `appServiceChargeRate` / `effectiveAppServiceChargeRate` | `ServiceCharges.appServiceChargeRate` (0.02); legacy API key `platformServiceChargeRate` on backend |

**RULE — ConfigurationService-first for admin-configurable rates:**

- **FORBIDDEN**: Using `CalculationConstants.FeeRates.traderCommissionRate` or `CalculationConstants.ServiceCharges.appServiceChargeRate` directly in business logic, ViewModels, or services.
- **REQUIRED**: Obtain admin-configurable rates from `ConfigurationServiceProtocol.effectiveCommissionRate` and `effectiveAppServiceChargeRate` (or the equivalent property for the specific rate).
- **REQUIRED**: Any service or ViewModel that performs a financial calculation involving an admin-configurable rate MUST accept `ConfigurationServiceProtocol` as a **non-optional** dependency (`any ConfigurationServiceProtocol`, not `(any ConfigurationServiceProtocol)?`). This eliminates all `?? CalculationConstants` fallback paths at the type level.
- **EXCEPTION**: ViewModels using the `reconfigure(with: AppServices)` / `attach()` pattern may keep `configurationService` as `(any ConfigurationServiceProtocol)?`, but MUST use `guard let` with a safe default — **never** force-unwrap (`!`) and never use `assertionFailure` in computed properties, because SwiftUI evaluates `body` (and all computed properties read there) **before** `.onAppear`/`.task` runs. Never use a `?? CalculationConstants` fallback either.
- **ALLOWED**: Using `CalculationConstants` values as the fallback inside `ConfigurationServiceProtocol` extension defaults — this is the single place where the fallback is wired.

```swift
// ✅ CORRECT — non-optional dependency, no fallback possible
private let configurationService: any ConfigurationServiceProtocol
let rate = configurationService.effectiveCommissionRate

// ✅ CORRECT — reconfigure/attach pattern: guard-let + safe default.
// SwiftUI evaluates body BEFORE .onAppear, so configurationService is
// legitimately nil on first render. The view re-renders after attach().
private var configurationService: (any ConfigurationServiceProtocol)?
guard let configurationService else { return 0.0 }
let rate = configurationService.effectiveCommissionRate

// ❌ FORBIDDEN — force-unwrap crashes if SwiftUI evaluates before reconfigure
// let rate = configurationService!.effectiveCommissionRate

// ❌ FORBIDDEN — assertionFailure also crashes in debug/Simulator builds
// assertionFailure("configurationService nil")  // ← still a crash

// ✅ CORRECT — fallback wired once inside the protocol extension
extension ConfigurationServiceProtocol {
    var effectiveCommissionRate: Double { traderCommissionRate }
}

// ❌ FORBIDDEN — optional with silent fallback
let rate = configurationService?.effectiveCommissionRate ?? CalculationConstants.FeeRates.traderCommissionRate

// ❌ FORBIDDEN — bypasses admin configuration entirely
let commission = grossProfit * CalculationConstants.FeeRates.traderCommissionRate
```

### Fixed Constants (not admin-configurable)

Order fees, exchange fees, foreign costs, tax rates, and payment limits are fixed at compile time and should be referenced directly from `CalculationConstants`.

### Persisted legal documents (invoices, credit notes, collection bills)

- **REQUIRED**: When the backend has persisted fee or commission rates (or fee line items) on the `Document`, settlement DTO, or invoice payload, **screens that display that artifact MUST use those stored values** for amounts and rates. Display must remain reconcilable with what was booked or printed.
- **FORBIDDEN**: `configurationService?.traderCommissionRate ?? CalculationConstants…` (or equivalent) on **document-detail** flows when the document or settlement already carries the rate — live config can change after issuance and would disagree with the stored record (poor audit trail / user trust).
- **ALLOWED**: `ConfigurationService` / `effective*` accessors for **pre-trade** estimates, onboarding copy, and any UI **before** a persisted document exists.

## When Adding New Fees, Rates, or Percentages

1. Decide: is this rate **admin-configurable** or **fixed**?
2. If **fixed**: add to `CalculationConstants` (appropriate struct), define both Double and display String, reference everywhere.
3. If **admin-configurable**: add to `ConfigurationServiceProtocol`, add a last-resort fallback in `CalculationConstants`, add the backend default in `backend/parse-server/cloud/utils/configHelper/defaultConfig.js` (`DEFAULT_CONFIG`), and ensure all callers go through `ConfigurationService`.

## Example Pattern (Fixed Constants)

```swift
// ✅ CORRECT - In CalculationConstants.swift
struct FeeRates {
    static let platformFeeRate: Double = 0.02
    static let platformFeePercentage: String = "2%"
}

// ✅ CORRECT - Usage
let fee = amount * CalculationConstants.FeeRates.platformFeeRate
Text("Fee: \(CalculationConstants.FeeRates.platformFeePercentage)")

// ❌ FORBIDDEN - Magic numbers
let fee = amount * 0.02
Text("Fee: 2%")
```

## Detection Guidelines

- **Before Committing**: Search codebase for duplicate numeric/string values
- **Code Review**: Check if the same value appears in multiple files
- **If Found**: Extract to `CalculationConstants` and reference the constant everywhere
- **Admin-configurable check**: If you see `CalculationConstants.FeeRates.traderCommissionRate` or `CalculationConstants.ServiceCharges.appServiceChargeRate` used directly in a calculation, this is a bug — replace with `ConfigurationService` access.

## Constants Location Guide

- **Financial/calculation constants (fixed)** → `CalculationConstants.swift`
- **Financial rates (admin-configurable)** → `ConfigurationServiceProtocol` (source of truth), `CalculationConstants.swift` (fallback only)
- **Backend defaults (admin-configurable)** → `backend/parse-server/cloud/utils/configHelper/defaultConfig.js` (`DEFAULT_CONFIG`)
- **UI constants** → `ResponsiveDesign.swift`
- **Feature-specific constants** → Feature's Models folder
- **Document/display placeholders** (z. B. Handelsplatz bis Produktion) → `TradeStatementPlaceholders` in `TradeStatementDisplayData.swift`
- **Emittent-Mapping (WKN → Anzeigename)** → Single source: `String.emittentName(forWKN:)` in `FIN1/Shared/Extensions/String+Emittent.swift`; nicht duplizieren

## Automated Detection

When adding fees, rates, or percentages:
- Check if the same numeric value (e.g., `0.02`, `0.10`) appears in multiple files
- Check if the same string value (e.g., `"2%"`, `"10%"`) appears in multiple files
- If found, extract to `CalculationConstants` and reference the constant everywhere
- Manual review: Search codebase for duplicate numeric/string values before committing
- **Admin-configurable audit**: grep for `CalculationConstants.FeeRates.traderCommissionRate` and `CalculationConstants.ServiceCharges.appServiceChargeRate` — every hit outside `ConfigurationServiceProtocol` extensions is a potential bug


