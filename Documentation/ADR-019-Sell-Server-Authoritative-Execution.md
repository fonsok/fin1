# ADR-019 – Sell: Server-Authoritative Execution (Symmetrie zu Paired Buy)

- **Status:** Accepted (Phase 1a implemented 2026-06-17; Phase 1b implemented 2026-06-17; Phase 2 implemented 2026-06-17; Phase 3a implemented 2026-06-17)
- **Datum:** 2026-06-17
- **Bezug:** `BACKEND_CALCULATION_MIGRATION.md`, `executionPriceResolver.js`, `executePairedBuy`, ADR-018, Gap-Analyse Monetary SSOT (2026-06)

## Kontext

Käufe mit Pool-Spiegel laufen über **`executePairedBuy`**: Intent (Menge, Symbol, Order-Typ), Server löst den Ausführungspreis via **`resolvePairedBuyExecutionPrice`** auf und persistiert Orders mit `executionPriceSource` / `serverReferencePrice`.

**Verkäufe** liefen bislang über **`OrderAPIService.saveSellOrder`** → Parse `Order` `beforeSave`, aber **`orderTriggerBeforeSave` wendete `resolveOrderExecutionPrice` nur auf `side === 'buy'` an**. Der Client setzte `price`, `grossAmount` und `totalAmount` aus UI-Schätzungen (`estimatedProceeds`). Das widerspricht dem Zielbild „Server = mathematische Wahrheit“ und der Buy-Symmetrie.

Dies ist **kein** „Client↔Server-Doppelrechner mit Cent-Gate“, sondern **ein autoritativer Server-Pfad** mit optionalem Client-Preis-Hint (wie bei Buy).

## Entscheidung

### Phase 1a (jetzt) — `Order.beforeSave` für Sell

1. **`orderTriggerBeforeSave`:** `resolveOrderExecutionPrice` + `applyExecutionPriceMetaToOrder` für **neue** Sell-Orders, wenn weder `executionPriceSource` noch `pairExecutionId` gesetzt sind (gleiche Ausnahme wie Buy).
2. **iOS `ParseOrderInput.from(sellOrder:)`:** `clientQuotedAt` mitsenden (wie Buy), damit Market-Orders eine frische Quote und MarketData-Toleranzprüfung erhalten.
3. **UI:** `estimatedProceeds` / „Erlös (geschätzt)“ bleiben reine Vorschau; Buchungsrelevant ist der nach `beforeSave` persistierte Order-Satz.

### Phase 1b (implemented 2026-06-17) — `executeSellOrder` Cloud Function

1. **`executeSellOrder`:** Server-orchestrierter Sell-Intent (`quantity`, `symbol`, `tradeId`, `clientOrderIntentId`); idempotent pro Trader+Intent; Preis via `resolveOrderExecutionPrice`; Fees via `calculateOrderFees`.
2. **iOS `OrderAPIService.saveSellOrder`:** ruft `executeSellOrder` statt direktem `createObject`; `clientOrderIntentId` = lokale `order.id` (Retry-sicher).
3. **`placeOrder` CF:** Sell erhält dieselbe Preis-Auflösung wie Buy (Legacy-API-Parität).

### Phase 1c (optional) — Sell-Finalize-Orchestrierung

Analog `commitPairedBuyExecution` für Sell-Status-Kopplung — nur wenn Paired-Sell-Legs oder Teil-Verkauf-Volumen es erfordern.

### Phase 2 — Legacy-Cleanup (implemented 2026-06-17)

Analog **P3b** (`InvoiceLocalSynthesisGate`):

1. **`InvestorCollectionBillLocalCalculationGate`:** `calculateCollectionBill(input:)` und `summarizeInvestment` nur in Tests via `withPermitted`.
2. **`calculateCollectionBillWithBackend`:** kein `localFallbackAfterBackendError` mehr — fehlender Beleg → `InvestorMonetaryServerOnlyError`.
3. **Prod-Call-Sites:** ViewModels, `InvestmentCashDistributor`, `ProfitDistributionService`, `OrderLifecycleCoordinator+Settlement` (Credit Note) ohne lokale Monetary-Fallbacks.
4. **Listen/Detail:** `canonicalSummaries` / `summarizeInvestmentFromServer` statt lokaler Aggregator-Summaries.

Offen (Phase 4+): `settlementGLOutboxEnabled` in Prod, ADR-018 P3c Decimal an Mongo-Grenzen.

### Phase 3 — Saldo SSOT (implemented 2026-06-17)

1. **`getUserCashBalance` CF:** liest `UserCashBalance.currentBalance` (mit Seed aus letztem `AccountStatement`).
2. **iOS customer display:** Closing balance from `getAccountStatement` merge (`balanceAfter` der letzten Zeile) — identisch Admin „Kundensicht“. `UserCashBalance` nur für Buchungs-Counter/Ops.
3. **`InvestorCashBalanceService.syncAuthoritativeBalance`:** Investment-Sheet und Quick-Stats nutzen Server-Saldo bei `investorMonetaryServerOnly`.
4. **`InvestorAccountStatementBuilder`:** keine lokalen Ledger-Fallbacks mehr für Kontoauszugszeilen.

Offen: ADR-009 `collectionBillServerLegs`, ADR-018 P3c `currentBalanceCents`.

### Phase 2 (ursprüngliche Roadmap-Notiz)

- Saldo-UI an `UserCashBalance` / `getAccountStatement` koppeln (→ Phase 3)

## Nicht-Ziele

- Cent-genauer Client↔Server-Vergleich als Ausführungs-Gate
- Vollständige Derivate-Margin-Engine
- Ersetzen von `executePairedBuy` durch Client-Berechnungen

## Konsequenzen

**Positiv**

- Sell-Preis folgt derselben MarketData-/Toleranz-Logik wie Buy
- Weniger Drift zwischen UI-Schätzung und Invoice/Settlement
- Inkrementeller Schritt ohne großes CF-Refactor

**Akzeptiert**

- Sell-Orchestrierung bleibt bis Phase 1b verteilt (`submitOrder` → Parse)
- Paired-Sell-Sync weiter über bestehende Trade/Order-Trigger

## Akzeptanzkriterien Phase 1a

- [x] Neue Sell-`Order` ohne `executionPriceSource` erhalten Server-`price` + `grossAmount`
- [x] iOS sendet `clientQuotedAt` bei Sell-Create
- [x] Regressionstests für Monetary Server-Only Policy (iOS)
- [ ] Staging: Sell-Invoice `grossAmount` = Server-`executionPrice` × `quantity` (manuell)

## Akzeptanzkriterien Phase 1b

- [x] `executeSellOrder` Cloud Function mit Idempotenz (`clientOrderIntentId`)
- [x] iOS `saveSellOrder` nutzt `executeSellOrder` (kein direktes `createObject`)
- [x] Unit-Tests Backend + iOS

## Referenzen

| Thema | Pfad |
|-------|------|
| Preis-Resolver | `backend/parse-server/cloud/utils/executionPriceResolver.js` |
| Order beforeSave | `backend/parse-server/cloud/triggers/orderTriggerBeforeSave.js` |
| iOS Sell persist | `FIN1/Features/Trader/Services/OrderAPIService.swift` |
| Paired Buy SSOT | `backend/parse-server/cloud/functions/tradingPairedBuyExecution.js` |
| Sell SSOT | `backend/parse-server/cloud/functions/tradingSellOrderExecution.js` |
| iOS Sell placement | `FIN1/Features/Trader/Services/OrderAPIService.swift` |
