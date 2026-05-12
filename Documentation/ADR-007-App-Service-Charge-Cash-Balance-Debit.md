# ADR-007: App Service Charge — Direct-Debit from Investor Cash Balance

## Status
Accepted (MVP shipped 2026-04-20). Phase-2 **backend stub**
(`bookAppServiceCharge` Cloud function, idempotent) shipped 2026-04-23.
iOS migration (stop embedding an `Invoice` inside the Document; call the new
Cloud function after the cash-balance debit) still tracked as follow-up.

## Date
2026-04-20 (original) · 2026-04-23 (Phase-2 backend stub)

## Context

The **App Service Charge** is a platform fee charged to the investor when a new
investment is created. It is **not** part of the trader's Commission (ADR-006,
`Documentation/RETURN_CALCULATION_SCHEMAS.md`) — it is a separate B2C fee for
running the platform, subject to VAT, and independent of whether the underlying
investment makes a profit or loss.

The rate is admin-configurable via `appServiceChargeRate` in the Configuration
Parse class (admin portal → Configuration → Financial). Default in
`backend/parse-server/cloud/utils/configHelper/defaultConfig.js` is `0.02`
(2 %); the rate in production at the time of this ADR is set by the admin team.

The Account feature (crypto trading) is **disabled** on the current deployment,
so the authoritative funds account for investors is the in-app **Cash Balance**
(`InvestorCashBalanceService` on iOS; server-side cash balance to be formalized
in Phase 2 — see below).

### Bugs this ADR closes

Pre-2026-04-20 the `beforeSave` trigger on the `Investment` Parse class
computed the service charge and then set

```js
investment.set('initialValue', serviceCharge.netAmount);
investment.set('currentValue', serviceCharge.netAmount);
```

i.e. it silently reduced the investment notional by `serviceCharge + VAT`. At
the same time the iOS client (`InvestmentCashDeductionProcessor`) processed a
**separate** debit against the investor cash balance for the exact same
service-charge amount and created an Invoice Document for it.

Result: the investor was effectively charged **twice** for the same platform
fee — once by the silent reduction of invested capital (which skewed the
mirror-trade basis, the pool share and `profitPercentage`) and a second time
by the cash-balance debit + Invoice. This ADR makes the server's investment
notional match the iOS model: **gross at `amount`**; service charge is a
separate debit only.

### Backend `createInvestment` under-required the balance

`createInvestment` in `backend/parse-server/cloud/functions/investment.js`
checked `getWalletBalance >= amount` only — it ignored the service charge, so
an investor with exactly `amount` cash could create an investment they did not
have enough funds to pay for once the service charge was posted. Fixed in
this ADR to require `amount + serviceChargeTotal`.

## Decision

1. **Investment notional is gross.** The `beforeSave` Investment trigger now
   sets `initialValue = amount` and `currentValue = amount` (full gross). The
   `serviceChargeRate / Amount / Vat / Total` fields are still populated on
   the object for reporting, tax and legal purposes — they are **not**
   subtracted from the notional.

2. **Service charge is a separate debit against Cash Balance.** The iOS
   `InvestmentCashDeductionProcessor` already performs this on the
   `InvestorCashBalanceService` at investment-creation time, in parallel with
   the investment-capital debit. When the Account feature is disabled, this
   is the authoritative cash-balance move for the investor. Server-side
   counterpart is tracked as Phase 2 (see below).

3. **Balance check at create AND confirm.** Both
   `createInvestment` and `confirmInvestment` require
   `balance >= amount + serviceChargeTotal`. The check is a **best-effort
   server-side guardrail**: it enforces only when a wallet balance source is
   available (`getWalletBalance` succeeds). On Wallet-disabled deployments,
   `getWalletBalance` throws `OPERATION_FORBIDDEN`; in that case the server
   accepts the request because the iOS client has already validated against
   `InvestorCashBalanceService`. The server never shadow-books — if the iOS
   validation is correct the server guardrail never fires; if it isn't, the
   guardrail stops the double-charge failure mode.

4. **Error messages include the required vs. available numbers** so the
   investor sees exactly the shortfall
   (`Unzureichendes Guthaben (benötigt X € für Investment + App Service Charge, verfügbar Y €)`).

## Contract

- `Investment.serviceChargeRate` (Number, 0–1): rate applied (admin config).
- `Investment.serviceChargeAmount` (Number, €): net service-charge amount.
- `Investment.serviceChargeVat` (Number, €): VAT on the service charge.
- `Investment.serviceChargeTotal` (Number, €): `serviceChargeAmount + serviceChargeVat`, NEW in this ADR — enables the `confirmInvestment` re-check to validate against the stored value (no re-derivation needed).
- `Investment.initialValue` / `currentValue` (Number, €): **equal to `amount`** at creation time (unchanged after), NOT `netAmount`. `currentValue` is updated only by settlement (`settleParticipation`) applying net profits.

## Phase 2 (tracked separately, not in this MVP)

The iOS client today creates an `Invoice` **struct** plus a `Document` of
`type: invoice` for the service charge. The server `Invoice` Parse class and
its `afterSave` trigger (`backend/parse-server/cloud/triggers/invoice/`)
post the actual **AppLedger** entries (`PLT-REV-PSC`, `PLT-TAX-VAT`,
`BANK-PS-NET`, `BANK-PS-VAT`) — but only when a real `Invoice` object is
saved. The iOS flow embeds the Invoice data inside a Document without saving
an `Invoice` object, so those AppLedger postings never fire today.

This is a gap for full GoB compliance, not a customer-visible bug (the
investor Cash Balance + contra posting are tracked client-side via
`InvestorCashBalanceService` and `BankContraAccountService`). Older unused
stub helpers (`recordBankContraPostingsForInvestment`,
`recordAppLedgerEntries`) used to live in the Investment triggers; **those
were removed** once Phase-2 `bookAppServiceCharge` shipped — AppLedger /
bank-contra postings stay the sole responsibility of `afterSave Invoice`
(`triggers/invoice/`), while activation calls `Parse.Cloud.run('bookAppServiceCharge',
…)` from `triggers/investmentTriggerAfterSaveActivate.js`.

Options considered for Phase 2 (decision deferred):

- **(a)** iOS calls a new Cloud function `bookAppServiceCharge` that creates
  the `Invoice` object server-side and lets `afterSave Invoice` do the
  AppLedger posting.
- **(b)** Backend's `afterSave Investment` (status → `active`) runs
  `bookAppServiceCharge` (wired in `investmentTriggerAfterSaveActivate.js`),
  which creates the authoritative `Invoice` and lets `afterSave Invoice`
  post AppLedger/contra rows; clients refresh documents as needed.
- **(c)** Server-side authoritative cash-balance account (formalize today's
  iOS `InvestorCashBalanceService` as a proper Parse class with triggers).

(b) is the closest to the existing code pattern and the recommended next step;
(c) is a broader refactor tied to the eventual re-enablement of the Wallet
feature.

### Phase-2 Backend Stub (2026-04-23)

Shipped as Cloud function
`bookAppServiceCharge({ investmentId })`, registered in
`backend/parse-server/cloud/functions/investment.js` (handler in
`functions/investmentBookAppServiceCharge.js`). It:

1. Loads the target `Investment`, validates ownership
   (session user must be the investor; `master key` also accepted for
   backend-driven calls).
2. Reads `serviceChargeAmount`, `serviceChargeVat`, `serviceChargeTotal`
   directly from the Investment (populated by the `beforeSave Investment`
   trigger — the single source of truth for the fee breakdown). If
   `serviceChargeTotal <= 0` the call returns `{ success: true, skipped: true,
   reason: 'no service charge' }` without side effects.
3. **Idempotency:** short-circuits if an `Invoice` with the same `batchId` and
   `invoiceType = 'service_charge'` already exists — returns the existing
   `invoiceId` with `skipped: true, reason: 'already booked'`. Retrying from
   the client (network glitches, app restarts during activation) never
   double-charges.
4. Creates the Parse `Invoice` object with
   `invoiceType='service_charge'`, `source='backend'`,
   `metadata.adrRef='ADR-007-Phase-2'`. The existing `afterSave Invoice`
   trigger (`backend/parse-server/cloud/triggers/invoice/`) is the
   unchanged SSOT for BankContra (`BANK-PS-NET` / `BANK-PS-VAT`) and
   AppLedger (`PLT-REV-PSC` / `PLT-TAX-VAT`) postings. We deliberately do
   not duplicate that posting logic here.

**iOS migration path.** Until the iOS client switches over, this Cloud
function is callable but unused in production. The migration to SSOT is:

- After `InvestmentCashDeductionProcessor` posts the cash-balance debit,
  iOS calls `bookAppServiceCharge({ investmentId })` instead of building a
  client-side `Invoice` inside a `Document`.
- iOS keeps creating the existing *display* `Document` (for PDF rendering
  in "Documents & Invoices"); only the ledger-side `Invoice` moves to the
  server.

**Test coverage.** Six Jest tests in
`backend/parse-server/cloud/functions/__tests__/investment.bookAppServiceCharge.test.js`
cover: successful create · idempotency · cross-investor rejection · zero-fee
skip · master-key call · missing-parameter rejection. The contract also
locks `Invoice.userId = investorId` and `Invoice.investmentIds = [id]` so
the `afterSave Invoice` trigger produces BankContraPostings that group
with the investor's other activity. Full `backend/parse-server` Jest suite
green (includes duplicate-guard + integration coverage).

### Phase-2 Activation Trigger (2026-04-23)

The backend no longer needs iOS to fire the invoice: `afterSave Investment`
(`backend/parse-server/cloud/triggers/investment.js`) now calls
`bookAppServiceCharge` with the master key whenever an Investment flips
from any other status to `active` **and** `serviceChargeTotal > 0`.

- The call is **best-effort**: a try/catch logs failures but never blocks
  the activation path (GoB receipt, wallet credit, notifications etc. all
  keep running). If the call fails, the weekly drift monitoring
  (`run-mirror-basis-drift-check.sh`) catches the missing ledger postings.
- Because the Cloud function is batch-level idempotent
  (`batchId + invoiceType`), it is safe to leave the iOS client-side
  Invoice path in place during the transition. Exactly one `Invoice`
  per batch gets persisted — whichever side wins the race short-circuits
  the other.
- **Bonus fix shipped in the same commit:** `triggers/invoice/` now
  reads `invoice.get('batchId')` first before falling back to the legacy
  `tradeId/orderId/invoice.id` chain. This aligns `PSC-<batchId>` posting
  groups across the iOS and backend paths, fixing a long-standing
  reporting split.
- **`beforeSave Invoice` duplicate guard (2026-04-23):**
  `triggers/invoiceDuplicateGuard.js` rejects a second Parse `Invoice` with
  the same (`invoiceType`, `batchId`) for `service_charge` /
  `platform_service_charge` (Parse error `DUPLICATE_VALUE`). This closes the
  race where the server already persisted `bookAppServiceCharge` but the iOS
  client still executes the fail-safe `addInvoice` fallback — without the
  guard, `afterSave Invoice` would emit a second BankContra + AppLedger set.
  Jest: `cloud/triggers/__tests__/invoiceDuplicateGuard.test.js`.

**Remote smoke (2026-04-23):** `bookAppServiceCharge` called via master
key on investment `0f3nWs3eyv` → creates Invoice `VpEbQSM01i` on first
call (`skipped:false`), returns same `invoiceId` on every subsequent
call with `skipped:true, reason:"already booked"`. BankContraPostings
created under `reference = PSC-<batchId>` as expected.

### Phase-2 Client Migration Flag (2026-04-23)

Rolled out behind an admin-controlled feature flag so the client path can
be switched to server-side Invoice creation without a new app release.

- **Flag:** Top-level `serviceChargeInvoiceFromBackend` on the `Configuration`
  object (default `false`). Exposed to clients via
  `getConfig.display.serviceChargeInvoiceFromBackend`. Editable through
  `requestConfigurationChange` from the Admin Portal: **non-critical**
  parameters (including this boolean) apply **immediately**
  (`requiresApproval: false`), same pattern as `walletFeatureEnabled`; only
  parameters listed in `CRITICAL_PARAMETERS` create a `FourEyesRequest`.
  Boolean parameter validator in
  `backend/parse-server/cloud/utils/configHelper/validateConfigValue.js`.
- **iOS client:**
  `FIN1/Features/Investor/Services/InvestmentCashDeductionProcessor.swift`
  branches on `configurationService.serviceChargeInvoiceFromBackend`:
  - **Flag `true`:** call
    `InvestmentAPIService.bookAppServiceCharge(investmentId:)` — the
    display `Document` (PDF) is still generated locally from the
    client-built `Invoice` value, only the *persisted* Parse `Invoice`
    is server-owned.
  - **Flag `false` (legacy):** unchanged — client writes the Invoice via
    `InvoiceService.addInvoice`.
- **Fail-safe fallback:** on transient errors (network, auth, outage) the
  client falls back to the legacy path so activation never blocks. For
  duplicate-protection responses (`DUPLICATE_VALUE` / "existiert bereits")
  the fallback is skipped because the server-side canonical Invoice already
  exists; this avoids a second write attempt.
- **iOS protocol change:** `InvestmentAPIServiceProtocol` gained a new
  method `bookAppServiceCharge(investmentId:) async throws -> String`
  and was marked `Sendable` so it can be used from `@MainActor`
  processors under Swift 6 strict concurrency.

**Rollout plan**
1. Flag deployed server-side with default `false` (done, 2026-04-23).
2. Enable `display.serviceChargeInvoiceFromBackend=true` in a non-prod
   environment; run an Investment activation; verify:
   - exactly one `Invoice` row per batch (`source='backend'`),
   - one pair of BankContraPostings under `PSC-<batchId>`,
   - weekly drift check remains `driftedDocuments=0`.
3. Flip to `true` in production via the Admin Portal (`requestConfigurationChange`,
   immediate apply unless the parameter is later added to `CRITICAL_PARAMETERS`).
4. After 2 successful weekly drift-check cycles with zero drift, remove
   the legacy `invoiceService.addInvoice(invoice)` call from
   `InvestmentCashDeductionProcessor` in a follow-up PR (Phase-2
   cleanup).

**Prod-Abnahme:** Schritt-für-Schritt-Checkliste inkl. Deploy, Backend-Smokes,
iOS-Sollverhalten und Rollback (inkl. Admin-Portal-Anzeigename):
`Documentation/RELEASE_CHECKLIST_2026-04-23_ADR-007_Service-Charge-Backend-Invoice.md`.

**Step 2 executed (fin1-server Dev, 2026-04-23)**

Dev-flip recorded for the runbook. Reproducible via master-key smoke (no iOS
build required — the same code path is exercised from Parse directly):

1. Flip: `Configuration.serviceChargeInvoiceFromBackend=true` via master-key
   `PUT /parse/classes/Configuration/<id>` → `getConfig.display.serviceChargeInvoiceFromBackend`
   observed as `true`.
2. Test artefact: synthetic Investment `QSpL8eU6ne` with
   `batchId=adr007-phase2-smoke-20260423-171234`, `serviceChargeTotal=59.50`.
3. First `bookAppServiceCharge` call → `{success:true, skipped:false}`:
   - `Invoice` `6j5sAUizde` created with `source='backend'`, `userId` +
     `customerId` + `customerName` + `investmentIds` populated.
   - `BankContraPosting` (×2) under `reference=PSC-<batchId>` (not
     `PSC-<invoiceId>` — the 2026-04-23 regression fix holds in production
     too), `investorId` + `investmentIds` correctly set.
   - `AppLedgerEntry` (×3) under `referenceId=<batchId>`: PLT-REV-PSC
     credit 50,00 €, PLT-TAX-VAT credit 9,50 €, PLT-CLR-GEN debit 59,50 €.
     Debit sum = credit sum (double-entry invariant).
4. Second call → `{success:true, skipped:true, reason:"already booked"}`
   and zero-delta on all three collections. Idempotency path exercised
   against the real `Parse.Query` + MongoDB index, not just the Jest mock.
5. Test artefacts deleted (1 Investment + 1 Invoice + 2 BankContraPosting +
   3 AppLedgerEntry) — post-cleanup counts all zero.

The flag stays `true` on the Dev server; the iOS Dev build picks it up via
the next `fetchRemoteDisplayConfig()` without redeployment. Production
rollout uses the same Admin Portal mechanism as step 3 (immediate apply
unless `CRITICAL_PARAMETERS` is extended).

## Operational Guardrails

- Idempotency: `createInvestment` stays idempotent w.r.t. Investment object
  creation (Parse save + `beforeSave`) — the only new work is the enhanced
  balance check. No new documents/entries are created by this ADR.
- Backfill: **not required**. Existing Investment documents with
  `initialValue = netAmount` remain readable. `profitPercentage` on those
  historical records is slightly overstated (denominator too small) but that
  is a minor analytics artefact, not a money-movement bug. A follow-up
  backfill can realign if/when Phase 2 lands.
- Regression: `backend/parse-server` `npm test` (93/93 tests) passes on the
  updated trigger and cloud function. No test fixtures needed: the
  `calculateServiceCharge` helper is unchanged (only the caller stops
  propagating `netAmount` into `initialValue`).

## Consequences

- `Investment.initialValue` semantics clarified: gross, not net.
- Double-charge failure mode eliminated (service fee was effectively
  charged twice — client-side debit and server-side silent reduction).
- `createInvestment` / `confirmInvestment` correctly gate creation on the
  full cash requirement.
- Admin reporting (`backend/parse-server/cloud/functions/admin/reports/summary.js`)
  now shows `grossProfit = currentValue - amount = 0` at creation (not
  `-serviceCharge`), i.e. a newly created investment shows neutral P&L
  until settlement — which is the accounting truth. Historical investments
  created under the old trigger will still show `-serviceCharge` as
  "opening loss" in the report; this is a non-issue for new ones.

## Related

- ADR-012 — Finance-Smoke, System-Health, App-Ledger (`Documentation/ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md`) — zentrale Ops-/Konsistenz-Checks neben `getMirrorBasisDriftStatus`
- ADR-006 — Server-Owned Return Percentage Contract
- ADR-008 — Per-Security / Per-Exchange Fee Profile (Phase B + C)
- `Documentation/RETURN_CALCULATION_SCHEMAS.md` — §4 App Service Charge
- `backend/parse-server/cloud/triggers/investment.js`
- `backend/parse-server/cloud/functions/investment.js`
- `FIN1/Features/Investor/Services/InvestmentCashDeductionProcessor.swift`
- `FIN1/Features/Investor/Services/InvestmentCreationService.swift`
- `backend/parse-server/cloud/functions/admin/opsHealth.js` —
  `getMirrorBasisDriftStatus` exposes the weekly reconciliation so
  admins can verify from inside the app that the `Invoice`-trigger →
  AppLedger/BankContra path stays in sync with the mirror-basis SSOT.
