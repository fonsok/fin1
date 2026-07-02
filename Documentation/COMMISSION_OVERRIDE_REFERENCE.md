# Per-User Commission & Limit Overrides — Referenz (SSOT)

**Stand:** 2026-07-02  
**Zielgruppe:** Entwicklung, Admin-Portal, Ops, QA

---

## Kurzfassung

| Override | Rolle | Global-Parameter | `_User`-Felder | 4-Augen-Request |
|----------|-------|------------------|----------------|-----------------|
| **Erfolgsprovision** (Bundle) | `trader` oder `investor` | `investorCommissionRateTotal`, `traderCommissionRate`, `appCommissionRate` | `commissionRateBundleOverride`, `commissionRateOverrideRole`, `commissionRateOverrideEffectiveFrom` | `user_commission_rate_bundle_change` |
| **App Service Charge** | `investor` | `appServiceChargeRate` | `appServiceChargeRateOverride`, `appServiceChargeOverrideEffectiveFrom` | `user_app_service_charge_change` |
| **Offene Depot-Positionen** | `trader` | `maxTraderOpenDepotPositions` | `maxOpenDepotPositionsOverride`, `maxOpenDepotPositionsOverrideEffectiveFrom` | `user_open_depot_limit_change` |

**SSOT Runtime:** Parse Server (`configHelper` Resolver). iOS liest keine per-user Overrides — Settlement und Enforcement laufen serverseitig.

**Globale Parameter** weiterhin über **Konfiguration** (`requestConfigurationChange` / `requestCommissionRateBundleChange` für das Provisions-Bundle). Per-user Overrides sind **zusätzlich** auf der Benutzer-Detailseite.

---

## Resolver-Priorität (Runtime)

### Commission (`resolveCommissionRateBundle.js`)

1. **Investment-Snapshot** (GoB, `commissionRateSnapshot.js`) — eingefroren bei Aktivierung
2. **Investor-Override** (`commissionRateBundleOverride`, Rolle `investor`)
3. **Trader-Override** (`commissionRateBundleOverride`, Rolle `trader`)
4. **Global** (`getCommissionRateBundle()`)

`effectiveFrom` steuert, ab wann ein genehmigter User-Override gilt (`overrideEffectiveFrom.js`).

### App Service Charge (`resolveAppServiceChargeRate.js`)

1. **Investor-Override** (`appServiceChargeRateOverride`)
2. **Global** (nach Kontotyp)

Einsatz: `investmentTriggerBeforeSave.js` (Service-Charge-Berechnung).

### Offene Depot-Positionen (`resolveMaxOpenDepotPositions.js`)

1. **Trader-Override** (`maxOpenDepotPositionsOverride`)
2. **Global** (`maxTraderOpenDepotPositions`)

Einsatz: `traderOpenDepotLimits.js` → `assertTraderCanOpenNewDepotPosition` in `executePairedBuy`.

---

## Admin-Portal

**Route:** `/users/:userId` — drei einklappbare Karten (`AdminCollapsibleCard`):

| Karte | Sichtbar für | API (Request) |
|-------|--------------|---------------|
| `UserCommissionRateOverrideCard` | `trader`, `investor` | `requestUserCommissionRateBundleChange` |
| `UserAppServiceChargeOverrideCard` | `investor` | `requestUserAppServiceChargeChange` |
| `UserOpenDepotLimitOverrideCard` | `trader` | `requestUserOpenDepotLimitChange` |

**Payload in `getUserDetails`:** `commissionControls`, `appServiceChargeControls`, `openDepotLimitControls` (Loader in `users*Controls.js`).

**Freigaben:** `/approvals` — Typen `user_commission_rate_bundle_change`, `user_app_service_charge_change`, `user_open_depot_limit_change`. Genehmigung: `approveRequest` (Requester ≠ Approver, Berechtigung `createCorrectionRequest` / `approveRequest`).

**UI:** Preset-Aufteilung wie globale Konfigurationskarte (`commissionRateTraderApp.ts`); optional `effectiveFrom`; „Override entfernen“ (`clearOverride`).

---

## Backend-Module

| Modul | Rolle |
|-------|--------|
| `usersRequestCommissionRateBundle.js` | 4-Augen-Antrag Commission |
| `usersRequestAppServiceCharge.js` | 4-Augen-Antrag Service Charge |
| `usersRequestOpenDepotLimit.js` | 4-Augen-Antrag Depot-Limit |
| `usersCommissionControls.js` | Admin-Detail-Payload Commission |
| `usersAppServiceChargeControls.js` | Admin-Detail-Payload Service Charge |
| `usersOpenDepotLimitControls.js` | Admin-Detail-Payload Depot-Limit |
| `fourEyes/approve.js` | Persistiert genehmigte Overrides auf `_User` |
| `fourEyes/reject.js` | Audit bei Ablehnung |
| `commissionRateSnapshot.js` | Investment-Snapshot für Settlement |
| `settlementCore/*` | Nutzt `createCommissionRateResolver` |

---

## Tests

### Jest (lokal)

```bash
cd backend/parse-server && npm test -- --testPathPattern='usersRequestCommission|usersRequestAppService|usersRequestOpenDepot|resolveCommission|resolveAppService|resolveMaxOpenDepot|overrideEffective|commissionRateSnapshot|traderOpenDepot'
```

37 Unit-Tests (Request-Handler, Resolver, Snapshot, Depot-Limits).

### E2E-Smokes (ioxbox / Tunnel, nach Deploy)

| Skript | Ablauf |
|--------|--------|
| `scripts/smoke-user-commission-rate-bundle-e2e.sh` | Admin beantragt Trader-Override → Finance genehmigt → `getUserDetails` prüft → Revert |
| `scripts/smoke-user-app-service-charge-e2e.sh` | Analog für Investor App Service Charge |
| `scripts/smoke-user-open-depot-limit-e2e.sh` | Analog für Trader Depot-Limit |

**Credentials:** `BA_PASSWORD` in `scripts/.env.server` (siehe `Documentation/DEV_PORTAL_LOGIN_SSOT.md`). Optional: `SMOKE_REQUESTER_EMAIL`, `SMOKE_APPROVER_EMAIL`, `SMOKE_TRADER_EMAIL`, `SMOKE_APPROVER_PASSWORD`.

**Post-Deploy:** alle drei Skripte in `scripts/post-deploy-smoke.sh` (Profile `full` und `admin`).

**Global vs. per-user:** `smoke-commission-rate-bundle-e2e.sh` testet **globale** Konfiguration; `smoke-user-*` testet **nutzerbezogene** Overrides.

---

## Verwandte Dokumentation

- Globale 4-Augen-Konfiguration: [`CONFIGURATION_4EYES_DEPLOYMENT.md`](CONFIGURATION_4EYES_DEPLOYMENT.md)
- Admin-Portal User Detail: [`FIN1_APP_DOCS/10_ADMIN_PORTAL_REQUIREMENTS.md`](FIN1_APP_DOCS/10_ADMIN_PORTAL_REQUIREMENTS.md)
- QA / Smoke-Liste: [`FIN1_APP_DOCS/05_TEST_QUALITAET.md`](FIN1_APP_DOCS/05_TEST_QUALITAET.md)
- Dev-Login & Smokes: [`DEV_PORTAL_LOGIN_SSOT.md`](DEV_PORTAL_LOGIN_SSOT.md)
