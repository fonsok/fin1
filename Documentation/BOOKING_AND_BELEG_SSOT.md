# Booking & Beleg SSOT (GoB)

**Paired Buy → Sell → Investor:** End-to-End-Invarianten und Ops-Check → [PAIRED_BUY_SELL_INVESTOR_INVARIANTS.md](./PAIRED_BUY_SELL_INVESTOR_INVARIANTS.md)

**Maßgeblich bei Widerspruch:**

| Beleg-Typ | SSOT-Modul |
|-----------|------------|
| Investor Collection Bill | `collectionBillBelegSnapshot.js` |
| Trader Kauf-/Verkaufsabrechnung (TBC/TSC) | `traderCollectionBillBelegSnapshot.js` |

## Prinzipien

1. **Keine Buchung ohne Beleg** — jede saldenwirksame Investor-Abwicklung referenziert einen archivierten `Document` (Collection Bill, Eigenbeleg, Invoice, …).
2. **Beleg = SSOT** — Buchungsbeträge kommen aus `Document.metadata` nach **einem** Berechnungslauf, nicht aus UI-Nachsummen.
3. **Fail-closed** — fehlende Legs oder verletzte Invarianten → kein `createCollectionBillDocument`, kein Settlement.
4. **Keine Doppelbuchung** — nach Trade-Settlement (`tradeSettlementPoolRelease`) kein `bookReleaseTrading` / kein zweites `investment_return` im Complete-Trigger.

## Collection Bill Invarianten (v2)

| Invariante | Formel |
|------------|--------|
| Nominal | `investmentNominal = totalBuyCost + residualAmount` |
| Gewinn | `grossProfit = netSellAmount − totalBuyCost` |
| Nach Provision | `netProfit = grossProfit − commission` (Investor: **eine** Zeile; `commission` = Summe gemäß `investorCommissionRateTotal` = `traderCommission` + `appCommission`) |
| Überweisung | `transferAmount = netSellAmount − commission` |

`totalBuyCost` und `residualAmount` leiten sich aus `buyLeg.residualAmount` und Investment-Nominal ab (gebuchter Split), nicht aus abweichender Zeilensumme.

### Einstand / Bezugspreis (Anzeige & Pool-Summary)

| Begriff | Formel | SSOT-Modul |
|---------|--------|------------|
| **Einstand pro Stück** | `(Kaufvolumen + Kaufgebühren) / Stück` = `totalBuyCost / quantity` | `legPriceMetrics.js` (`costBasisPerShareFromBuyLeg`, `enrichBuyLegWithPriceMetrics`) |
| **Netto-Verkauf pro Stück** | `(Verkaufsvolumen − Verkaufsgebühren) / Stück` | `netSellPricePerShareFromSellLeg` |
| **Bid / Ask (nominell)** | `grossAmount / quantity` ohne Gebühren im Stückpreis | `tradeBuySideMetrics` / `tradeSellSideMetrics` |

Collection Bills und Admin-Beleg (`usersDetailStatementsAndWallet`) liefern `buy.costBasisPerShare` und `sell.netSellPricePerShare` aus angereicherten Legs. Der Summary-Report nutzt für **Pool-Spiegel** den **Trade-Leg-Einstand** (`attachLegPriceMetricsToSnapshot` → `aggregatePoolAtCostBasis`), nicht den reinen Bid-Kurs.

Nach Aktivierung wird die gleiche gebuchte Gesamtkaufkosten-Größe zusätzlich auf **`Investment.poolTradingAmount`** persistiert (und kann aus Beleg-Metadaten `totalBuyCost` / `poolTradingAmount` nachgezogen werden), damit Clients das Nominal (`amount` = Reservierung) von der Kaufseite unterscheiden können.

## Pipeline

### Investor Collection Bill

```
computeInvestorBuyLeg + deriveMirrorTradeBasis
  → buildCollectionBillBelegSnapshot (Invarianten)
  → createCollectionBillDocument (metadata persistieren)
  → AccountStatement + investmentEscrow (nur Belegwerte)
```

### Trader Collection Bill (TBC / TSC)

```
Trade + Order (+ optional Invoice für Wertpapierzeile / Handelsplatz)
  → buildTraderCollectionBillBelegSnapshot (Invarianten, belegSchemaVersion: 1)
  → createTradeExecutionDocument (metadata + accountingSummaryText persistieren)
  → trade_buy / trade_sell (Ledger-Referenz auf Document)
```

**Lesen (Admin / App):**

| Client | API |
|--------|-----|
| Admin | `getDocumentByObjectId` / `getDocumentByLedgerReference` (`getFinancialDashboard`) |
| iOS Trader | `getTraderDocumentBelegDetail` (Session, nur eigene Belege) |

Beide: `enrichTraderDocumentMetadata` (Alt-Belege) → `projectDocumentDetail` / `traderCollectionBillDisplaySections` — **keine** zweite Gebührenberechnung in der UI.

**Nicht SSOT (nur Anzeige-Hilfe):** iOS `TradeStatementDisplayDataBuilder` aus `Invoice` — Zielbild: offizieller Beleg = Parse `Document` mit Snapshot; Invoice-Rebuild nur Fallback.

**Trader-Provision (Trade-Überblick, nicht Beleg-Erzeugung):** Anzeige der Gutschriftssumme pro Trade aus Beleg-Inbox + `commission_credit` der Kundentimeline — nur **Trader-Anteil** (`traderCommission`), nicht die App-Erfolgsprovision — [`TRADER_COMMISSION_DISPLAY_SSOT.md`](TRADER_COMMISSION_DISPLAY_SSOT.md).

**App-Erfolgsprovision (Plattform, intern):** Eigenbeleg-Typ `appCommissionEigenbeleg` (Präfix **EAP**) am **Trader-/Settlement-Trade** — GoB **vor** App-Ledger-Buchung `PLT-LIAB-COM` → `PLT-REV-COM` (`transactionType: appCommission`, `leg: app_commission`). Metadaten: Betrag, `appCommissionRateSnapshot`, Bruttogewinn-Basis, SKR03 1700→8400.

**Pool-Mirror (intern):** Eigenbeleg-Typ `poolMirrorExecutionEigenbeleg` (PMBC/PMSC) am **Mirror-Trade** — Klartext mit Reserved / Pool-Einlage / Residual / Investoren; verknüpft Trader-TBC nur als Referenz. Admin Summary verlinkt **nicht** mehr die Trader-TBC unter „Pool-Mirror“.

**Legacy-Backfill (Admin):** `backfillTraderCollectionBillBeleg` (Trader TBC/TSC), `backfillPoolMirrorExecutionEigenbeleg` (Pool PMBC aus Trader-TBC + Participations; Parameter `traderDocumentNumber`, `poolTradeId`, `executionType`), `backfillAppCommissionEigenbeleg` (fehlende EAP für bereits gebuchte App-Provision-GL).

### Kontoauszug & Settlement-GL (`utils/accountingHelper/`)

| Datei | Rolle |
|--------|--------|
| `statements.js` | **Fassade** — gleiche öffentliche API wie bisher; bestehende `require('…/statements')`-Imports bleiben gültig. |
| `accountStatementWriter.js` | Kontoauszugszeilen (`bookAccountStatementEntry`, …), Cash/Chain/Kompensation (Phase 3b, vgl. Audit-Abschnitt unten). |
| `settlementGLRules.js` | `SETTLEMENT_GL_RULES`, Regel-Lookup, Rollenzuordnung. |
| `settlementGLPoster.js` | Settlement-Posting (`bookSettlementEntry`), Order-Fee-Breakdown, GL-Pairs. |

## Settlement-Robustheit: Per-Investor-Isolation

`settleAndDistribute` (Fassade `utils/accountingHelper/settlementCore.js` → `settlementCore/`: `poolSettlementScope`, `participationSettlementLoop`, `traderCommissionCredit`, `settleAndDistribute`) isoliert jeden Investor des Pool-Trades in einen eigenen `try/catch`. Ein einzelner Fehler (korrupte `Investment`-Row, transienter Save-Konflikt etc.) bricht **nicht** mehr die gesamte Pool-Abrechnung ab — die übrigen Investoren werden trotzdem versucht.

## Strukturiertes Audit-Logging

GoB-kritische Buchungspfade (`utils/accountingHelper/settlementCore.js`, `investmentEscrow.js`, `settlementBackfill.js`) schreiben über `utils/structuredLogger.js` JSON-Logzeilen mit festen Feldern (`tradeId`, `tradeNumber`, `investmentId`, `businessCaseId`, `participationId`, `billId`, `nominal`, `tradingAmount`, `availableAmount`, `transferAmount`, `gap`, `error`, …) statt nur `console.log`-Texte. Beispiel-`event`-Werte: `escrow.split.book`, `escrow.split.imbalance`, `escrow.activation.split`, `escrow.activation.poolTradingAmount.persistFailure`, `escrow.payout.gap`, `settlement.participation.failure`, `settlement.backfill.investment`. **Settlement-Retry-Queue** (`utils/accountingHelper/retryQueue.js`, Worker in `main.js`): `settlement.retry.enqueue`, `settlement.retry.process.start`, `settlement.retry.process.done`, `settlement.retry.process.reschedule`, `settlement.retry.process.terminal`, `settlement.retry.batch`, `settlement.retry.worker.tick`, `settlement.retry.worker.failure`. **Trade afterSave (nur Settlement-Scheduling):** `triggers/tradeTriggerAfterSave.js` — `settlement.retry.trigger.drain`, `settlement.retry.trigger.drainFailure`, `settlement.retry.trigger.enqueueFailure` (Felder u. a. `tradeId`, `tradeNumber`, `businessCaseId`, `source`, `processed`). **Admin Cloud (direktes `settleAndDistribute`):** `functions/admin/financialSettlementRepair.js` — `settlement.admin.backfillTradeSettlement.start` / `.done` / `.failure` (`initiatedByUserId` wenn Session). **Repair (`repairTradeSettlement`, re-settle):** `settlement.admin.repair.reSettle.start` / `.done` / `.failure` in `utils/accountingHelper/repair.js`. **Repair (gesamter Lauf inkl. Dry-Run):** `settlement.admin.repairTradeSettlement.request` (Admin-Handler), `settlement.admin.repair.repairTradeSettlement.start`, `settlement.admin.repair.repairTradeSettlement.complete` (Dry-Run oder nach destruktivem Pfad), `settlement.admin.repair.repairTradeSettlement.failure` (vorzeitiger Abbruch mit Re-Throw). **Preflight:** `settlement.admin.repair.repairTradeSettlement.invalid` (fehlende `tradeId`), `settlement.admin.repair.repairTradeSettlement.loadTradeFailure` (`Trade.get` schlägt fehl), `settlement.admin.repair.repairTradeSettlement.preflightQueriesFailure` (parallele Queries auf Dokumente/Statements/Commissions/Participations nach geladenem Trade; Feld `phase: "preflight_queries"`). **Balance-Race-Detection (Phase 3a, `utils/accountingHelper/accountStatementChainGuard.js`):** nach jedem `bookAccountStatementEntry`-`save` werden die beiden neuesten Zeilen pro `userId` nachgelesen und auf Ketten­konsistenz (`previous.balanceAfter === inserted.balanceBefore`, Toleranz < 0,5 ct) geprüft. Events: `accountstatement.balance.chainBreak` (Bruch entdeckt; Felder `userId`, `newestEntryId`, `previousEntryId`, `entryType`, `tradeId`, `tradeNumber`, `investmentId`, `investmentNumber`, `businessCaseId`, `previousBalanceAfter`, `newestBalanceBefore`, `newestBalanceAfter`, `delta`, `amount`) und `accountstatement.balance.chainBreak.guardFailure` (Detection-Query selbst schlug fehl — Erfolgspfad bleibt unbeeinflusst). **Phase 3b — atomare Saldo-Linearisierung (`utils/accountingHelper/userCashBalanceAtomic.js`, Schema `gob_user_cash_balance_v1`):** `bookAccountStatementEntry` (`accountStatementWriter.js`, importierbar weiter über Fassade `statements.js`) ermittelt `balanceBefore`/`balanceAfter` nicht mehr per letztem `AccountStatement`-Read, sondern per MongoDB `findOneAndUpdate` mit `$inc` auf `UserCashBalance.currentBalance` und `returnDocument: 'before'` (gleiche DB wie `PARSE_SERVER_DATABASE_URI`). Fehlende `UserCashBalance`-Zeile: `ensureUserCashBalanceSeeded` legt sie aus dem letzten `AccountStatement.balanceAfter` an (idempotent). Schlägt das Speichern der neuen `AccountStatement`-Zeile fehl, wird `$inc` mit negativem Betrag kompensiert (`compensateUserCashBalanceAdvance`); Audits: `accountstatement.balance.advanceFailure`, `accountstatement.balance.advanceRollback`, `accountstatement.balance.advanceRollbackFailure`, `accountstatement.balance.advanceRollbackCritical`. **Admin-Backfill:** `backfillUserCashBalanceFromStatements` (`functions/admin/financialUserCashBalanceBackfill.js`, `dryRun` default `true`, `limitUsers`) setzt `currentBalance` pro User auf den letzten Kontoauszugs-Endstand. **Wichtig:** Parse speichert Timestamps in Mongo als `_created_at` (snake_case). Der Backfill iteriert `userId`s via `distinct` und holt pro User die letzte Zeile mit `findOne` + Sort `{ _created_at: -1, _id: -1 }` — kein `$last`-Aggregation, weil das in Mongo 4.x nicht deterministisch ist. **Admin-Read-Only-Prüfung:** Cloud Function `verifyAccountStatementChain` (`functions/admin/financialVerifyAccountStatementChain.js`, in `financial.js` registriert) — Parameter `userId` (Pflicht); Antwort u. a. `validChain`, `entryCount`, `firstChainBreak`, `firstArithmeticBreak`, `chainBreaksPreview` / `arithmeticBreaksPreview` (je max. 10), `sumMatchesLastClosing`. Zugriff wie andere Financial-Repairs: Session mit Admin-Rolle oder Master Key. Abschluss-Audit: `admin.accountstatement.verifyChain`. Sensitive Felder (`password`, `sessionToken`, `masterKey`, `accessToken`, `refreshToken`, `authData`, `secret`) werden vor der Serialisierung gefiltert; bei Enqueue wird nur `contextKeys` (Schlüsselliste von `lastContext`) geloggt, keine vollständigen Kontext-Objekte.

Strikt nach GoB: Die **Trader-`creditNote`** wird in einem Aufruf mit Failures **nicht** erstellt (keine Teilbuchung). Stattdessen wirft die Funktion am Ende einen aggregierten Fehler mit allen `participationId`/`investmentId`/`error`-Triplets → `SettlementRetryJob` retried den gesamten Trade. Da `settleParticipation` via `trySettleFromExistingBill` idempotent ist (existierende `investorCollectionBill` + Backfills greifen wieder), werden bereits erfolgreiche Investoren beim Re-Run deduplicated und nur die fehlerhaften neu versucht.

Permanent fehlschlagende Investoren landen nach `RETRY_SCHEDULE_MINUTES` (1, 5, 15, 60, 180, 720) im Status `failed` → Admin-Tooling (`financialSettlementRepair`) übernimmt.

## Gebühren-Defaults (SSOT)

`utils/helpers.js::calculateOrderFees` zieht **alle** Defaults aus `utils/configHelper/defaultConfig.js` → `DEFAULT_CONFIG.financial`. Es gibt **keine** zweite Hardcode-Quelle mehr. Aufrufer dürfen ein optionales `config`-Objekt übergeben (`Investment.feeConfigSnapshot`, `Configuration.financial` oder `trade.feeConfig`) — fehlende Keys fallen auf `DEFAULT_CONFIG.financial` zurück. Explizite `0`-Werte werden respektiert (`Object.prototype.hasOwnProperty`).

## feeConfigSnapshot (Gebührenbasis eingefroren)

Bei **neuer** Investment-Reservierung setzt `investmentTriggerBeforeSave.js` das Feld `feeConfigSnapshot` (Kopie der aktiven `Configuration.financial`). `mergeInvestorFeeConfig` (`accountingHelper/feeConfigSnapshot.js`) bildet die effektive Gebührenkonfiguration für Investor-Mirror-Legs als **`feeConfigSnapshot` ∪ `trade.feeConfig`**, sonst **`live financial` ∪ `trade.feeConfig`** (Legacy-Investments ohne Snapshot). Verwendung: Pool-Aktivierung (`ensureReserveCapitalTradeSplitOnActivation`), Settlement (`settleParticipation`), Admin-Repair (`financialSettlementRepair`).

Schema-Feld-Anlage und Audit: **`Documentation/SCHEMA_MIGRATIONS.md`** (`SchemaMigration` + `runPendingSchemaMigrations`).

## Investment-Reservierung anlegen (Create-Sync, Idempotenz)

Investor-Splits werden **nicht** mehr als lose Folge von REST-`POST` auf `Investment` angelegt. SSOT für das Anlegen:

```
iOS InvestmentService (batchId + sequenceNumber lokal)
  → Cloud Function createInvestmentSplits (ein Request pro Batch)
  → pro Split: Parse save Investment (beforeSave + afterSave bookReserve)
```

| Element | Regel |
|---------|--------|
| **Idempotenz** | Logischer Schlüssel **`(investorId, batchId, sequenceNumber)`**. Existiert die Kombination bereits, antwortet die Function mit dem vorhandenen `investmentId` (`idempotentReplay`). Kein zweites `bookReserve` für denselben Split. |
| **Duplicate-Guard** | `investmentDuplicateGuard.js` im `beforeSave` (zusätzlich zur Function-Lookup-Logik). |
| **`investmentNumber`** | Vergabe in `investmentTriggerBeforeSave` über **`generateInvestorInvestmentNumber(investorId)`** — Format `INV-YYYY-NNNNNNN`, **Sequenz pro Investor**, nicht global eindeutig. |
| **DB-Index** | Mongo **`unique + sparse`** auf **`(investorId, investmentNumber)`** (Migration `investment_number_per_investor_compound_unique_v1`). Ein globaler Unique-Index nur auf `investmentNumber` widerspricht dem Nummernmodell und erzeugt E11000 zwischen verschiedenen Investoren. |
| **`traderId`** | Parse `_User.objectId` des Traders. iOS: `MockTrader.backendTraderId` (Hydration `discoverTraders`); Server-Fallback `resolveTraderParseUser` wenn noch Mock-UUID übermittelt wird. |
| **Pool-Mirror-Cap** | Vor Anlage: `validatePoolMirrorReservationCapacity` in der Function (Summe **neuer** Splits); pro Split erneut in `beforeSave`. |
| **Fehler / Orphan** | `afterSave` kann `bookReserve` fehlschlagen, obwohl Parse die Zeile schon persistiert hat → **`rollbackOrphanInvestmentAfterFailedReserve`** (Einzel-Split). **Batch:** scheitert ein späterer Split → **`rollbackBatchCreatedSplits`** (Reservierung auflösen + Zeile entfernen, LIFO). Client: Reconcile/Fetch nach Duplicate, nicht sofort alles lokal verwerfen. |

**Nicht verwechseln mit:** Settlement/Collection Bill (nach Trade-`completed`) — dort gilt weiterhin Beleg-SSOT oben; Create-Sync betrifft nur Status **`reserved`** und Escrow-Reservierung.

**Implementierungs-Guide (MVVM, Tests, Deploy):** [`Documentation/ENGINEERING_GUIDE.md`](ENGINEERING_GUIDE.md) (Abschnitt *Investment anlegen*).

## Code-Modulstruktur (`documents.js`)

Persistierung von Parse-`Document`-Zeilen: Fassade **`accountingHelper/documents.js`** → **`documents/publicSurface.js`** (Tier 1: 8× `create*`/`ensure*`, Tier 2: Return-% + `resolveDocumentRefForFeeRefund`), Implementierung unter **`accountingHelper/documents/`**:

| Modul | Verantwortung |
|-------|----------------|
| `shared.js` | `applyBusinessCaseIdToDocument`, `formatEuroDe`, `formatDateTimeDe` |
| `creditNote.js` | `createCreditNoteDocument` |
| `collectionBill.js` | `createCollectionBillDocument`, `returnPercentage`-Invarianten |
| `reservationEigenbeleg.js` | `createInvestmentReservationEigenbelegDocument` (vor `investmentEscrow.bookReserve`) |
| `partialSellEigenbeleg.js` | `createPartialSellInternalBeleg` (ADR-015) |
| `appCommissionEigenbeleg.js` | `createAppCommissionEigenbeleg` (GoB vor App-Ledger Erfolgsprovision, EAP) |
| `walletReceipt.js` | `createWalletReceiptDocument` |
| `tradeExecution.js` | `createTradeExecutionDocument`, `findExistingTradeExecutionDocument` |
| `serviceChargeInvoice.js` | `ensureServiceChargeInvoiceDocument` |
| `feeRefundRefs.js` | `resolveDocumentRefForFeeRefund` (4-eyes fee_refund) |

Beleg-**Metadaten-SSOT** (Beträge/Invarianten vor Persistenz): `collectionBillBelegSnapshot.js` (Investor CB); Trader TBC/TSC — Fassade **`traderCollectionBillBelegSnapshot.js`**, Submodule **`traderCollectionBillBelegSnapshot/`**:

| Modul | Verantwortung |
|-------|----------------|
| `shared.js` | Schema-Version, Toleranz, `formatEuroDe`, Backfill-Checks |
| `snapshotHelpers.js` | Instrument-Zeile, Order-Like, `totalWithFees`-Invariante |
| `buildCollectionBill.js` | `buildTraderCollectionBillBelegSnapshot` (Kauf/Verkauf inkl. Teilverkauf) |
| `summaryText.js` | `formatTraderCollectionBillSummaryText` (Klartext) |
| `tradingFeesBeleg.js` | `buildTradingFeesBelegSnapshot` (TFS intern) |
| `publicSurface.js` | Tier-Manifest (7 Fassaden-Exports; `TOLERANCE`/`formatEuroDe*` nur in `shared.js`) |

**Öffentliche API (Fassade → `traderCollectionBillBelegSnapshot/publicSurface.js`):** Tier 1 Beleg-Build (`build*`, `format*SummaryText`, `traderCollectionBillDisplaySections`); Tier 2 Backfill (`TRADER_COLLECTION_BILL_SCHEMA_VERSION`, `isUsableTraderBelegSummaryText`, `metadataNeedsBackfill`). Contract-Test: `traderCollectionBillBelegSnapshot.publicSurface.test.js`.
| `displaySections.js` | `traderCollectionBillDisplaySections` (Admin-UI) |

## Trade-Settlement (Async)

`tradeTriggerAfterSave.js` stößt nach `syncMirrorTradeWhenTraderLegCompletes` nur noch `SettlementRetryJob` an und plant einen kurzen `processDueSettlementRetries`-Drain (`setImmediate`); die eigentliche Abrechnung läuft wie bisher im bestehenden Worker (`main.js`, 60s-Intervall). Finale Collection Bills: `createCollectionBillDocument` mit `allowIdempotentUpsert: true` aktualisiert ein vorhandenes `investorCollectionBill` zu `(investmentId, tradeId, source=backend)` statt einer zweiten CB-Nummer (Teil-Sell-Deltas rufen weiterhin **ohne** Upsert auf).

## Paired Buy: Mirror-Sync & Pool-Ökonomie

Fassaden mit `publicSurface.js` (ADR-014, GOBD Buy-Immutability):

| Fassade | Submodule | Verantwortung |
|---------|-----------|---------------|
| `utils/pairedTradeMirrorSync.js` | `legResolution.js` | TRADER ↔ MIRROR_POOL Lookup, `isPairedTraderLegTrade`, Idempotenz-Probe |
| | `sellSync.js` | `applyMirrorSellSyncFromTraderLeg` (**package-internal**) — nur Sell-Felder spiegeln |
| `utils/poolMirrorEconomics.js` | `aggregatePool.js` | `aggregatePoolInvestmentEconomics`, Snapshot-/Cost-Basis-Pfad |
| | `traderSellMath.js` | `resolvePoolSoldQtyCumulative`, Teilverkauf-Deltas (`TRADER_FULL_SELL_EPSILON` package-internal) |
| | `constants.js` | `ACTIVE_INVESTMENT_STATUSES` (package-internal) |

**Öffentliche API:** `pairedTradeMirrorSync/publicSurface.js` (6 Exports: 2 Sync-Use-Cases + 4 Leg-Resolution); `poolMirrorEconomics/publicSurface.js` (10 Exports: Aggregation/Queries + Sell-Math). Contract-Tests: `pairedTradeMirrorSync.publicSurface.test.js`, `poolMirrorEconomics.publicSurface.test.js`; Buy-Guard: `pairedTradeMirrorSync.buyImmutability.test.js` (liest `sellSync.js`).

**RBAC:** `utils/permissions.js` → `permissions/publicSurface.js` (9 Exports: Guards + Konstanten + Admin-Introspection; `isValidRole`/`get*Roles` nur in `roles.js`).

## Investor-Kontoauszug (Kundensicht / App)

Merge-SSOT: Fassade **`utils/investorAccountStatementMerge.js`** (unveränderte `require`-API), Implementierung unter **`utils/investorAccountStatementMerge/`**:

| Modul | Verantwortung |
|-------|----------------|
| `shared.js` | Konstanten (`INVESTOR_STMT_SOURCE_LIMIT`, Escrow-Typen), `dedupeParseObjectsById`, `iso` |
| `clientLiability.js` | `summarizeClientFundsFromEscrowRows` (AVA/RSV/PTR-Netto) |
| `avaLedger.js` | AVA-Signed-Amount, `syntheticEntryTypeFromLedgerRow`, Residual-Dedup |
| `dataLoading.js` | `loadInvestorAccountStatementSourceData`, Investment-/Escrow-Queries |
| `mergedTimeline.js` | `buildInvestorMergedTimeline` (Kundensicht) |
| `ledgerGoBTimeline.js` | `buildInvestorLedgerGoBTimeline` (Admin Ledger GoB) |
| `collectionBillFeeGranularity.js` | `applyInvestorGoBCollectionBillFeeGranularity` |
| `apiRows.js` | `mergedTimelineToApiRows`, Pagination |
| `publicSurface.js` | Tier-Manifest + Exportliste für die Fassade (keine Logik) |

**Öffentliche API (Fassade → `investorAccountStatementMerge/publicSurface.js`):**

| Tier | Exports | Neuer Code |
|------|---------|------------|
| **1 — Customer** | `loadInvestorAccountStatementSourceData`, `buildInvestorMergedTimeline`, `buildInvestorLedgerGoBTimeline`, `mergedTimelineToApiRows`, `mergedTimelineToDescendingApiRows` | Ja |
| **2 — Admin** | `applyInvestorGoBCollectionBillFeeGranularity`, `summarizeClientFundsFromEscrowRows`, `fetchInvestorEscrowLedgerRows`, `listInvestorInvestmentIds`, `syntheticEntryTypeFromLedgerRow` | Ja (Admin/`getUserDetails`) |
| **3 — Package-internal** | `signedAmountFromAvaLedgerRow`, `buildResidualReturnDedupKeys`, `isDuplicateAvaResidualLedgerRow`, `fetchAccountStatementRowsForInvestor`, `fetchInvestorAvaCashLedgerRows`, `timelineRowMatchesEntryType` | **Nein** — Submodule + direkte Tests |

Contract-Test: `utils/__tests__/investorAccountStatementMerge.publicSurface.test.js`.

Genutzt von `getAccountStatement` (nicht-Trader) und Admin **Kundensicht** (`buildInvestorMergedTimeline`).

- `investment_activate` erscheint nicht (interne RSV→PTR-Umschichtung).
- AVA-Zeilen `tradeSettlementPoolRelease` und `tradeSettlementProfitRelease` werden **nicht** angezeigt: sie sind nur die buchhalterische Aufteilung desselben Cashflows, der bereits als `investment_return` in `AccountStatement` steht (vgl. `accountStatementWriter.js` / `settlementGLPoster.js` über Fassade `statements.js` sowie `investmentEscrow.js`). Laufender Saldo wird nach dem Filtern neu berechnet.
- Vollständige Parse-`AccountStatement`-Chronologie inkl. `investment_activate` bleibt der Admin-Ansicht **Ledger (GoB)** vorbehalten; dort werden zusätzlich AVA-`reserve`-Zeilen für noch nicht aktivierte Investments sowie **`appServiceCharge`** auf AVA eingeblendet (`buildInvestorLedgerGoBTimeline`) — App-Servicegebühr läuft über Rechnung/Trigger ohne paralleles `AccountStatement`. Optional: `expandTraderLedgerStmtEntries` (Order-Math wie Trader). Mit vorhandenem Collection-Bill-Metadaten-Payload ersetzt `applyInvestorGoBCollectionBillFeeGranularity` aggregierte `trading_fees` desselben Trades durch **Einzelzeilen** laut Beleg: Kaufgebühren am `investment_activate`, Verkaufsgebühren nach letzter `residual_return` (Fallback `investment_return` / `trade_sell`). **Gesamtkaufkosten / Überweisungsbetrag** und Tabellen-Nachweis bleiben im Admin-Feld `investorCollectionBills` / UI **Beleg-Nachweis** (`getUserDetails` → Fassade `usersDetailStatementsAndWallet.js`, Submodule `usersDetailStatementsAndWallet/`).

**Trade-Settlement-Reparatur (admin):** Fassade `accountingHelper/repair.js` → `repair/` (`queries`, `batchDestroy`, `investmentRecalc`, `repairTradeSettlement`).

## iOS

- **Investor CB:** `InvestorCollectionBillBelegReconciliation` — `displayTotalBuyCost`, `bookedTransferAmount` aus Metadata; lokale Rechnung nur bei fehlendem Beleg; bei Drift Warnung `backendBelegInconsistent`.
- **Trader TBC/TSC:** [`Documentation/IOS_TRADER_BELEG_SSOT.md`](IOS_TRADER_BELEG_SSOT.md) — Phase 1: `TraderCollectionBillBelegSnapshotView` aus `Document.accountingSummaryText`; `TradeStatementView`/Invoice nur Fallback.
