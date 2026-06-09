# ADR-015 – Partial-Sell GoB: Interner Beleg & Escrow 1593 (PPS)

- **Status:** Accepted
- **Datum:** 2026-06-06
- **Bezug:** `ADR-010`, `ADR-014`, `INVESTMENT_ESCROW_LEDGER_SKETCH.md`

## Problem

Bei **Teilverkäufen** (Partial Sells) im Pool-Mirror-Trade wurde bisher:

1. pro Partial Sell eine **Investor Collection Bill** erzeugt,
2. sofort `investment_return`, `commission_debit` und Steuerbuchungen auf dem **Kunden-Kontoauszug** gebucht,
3. der **Trader-Verkaufsbeleg** nur **einmal pro Trade** (nicht pro `sellOrderId`) idempotent gehalten.

Das verletzt GoB und Produktlogik:

- **Keine Kunden-Auszahlung** vor offiziellem Trade-Ende (Collection Bill).
- **Jede Buy/Sell-Order** des Traders braucht einen eigenen Beleg + `trade_sell` im Kontoauszug.
- **Jeder Partial Sell** braucht einen **internen Buchungsbeleg** und eine **Escrow-Umschichtung** (1592 → 1593), nicht `investment_return`.

## Entscheidung

### A) Neues Escrow-Konto CLT-LIAB-PPS (SKR03 1593)

| Code | SKR03 | Rolle |
|------|-------|-------|
| **CLT-LIAB-PPS** | 1593 | Kundenguthaben – **Teilverkauf aus Pool-Trade** (ausstehend bis Trade-Ende) |

Zwischenkonto zwischen **PoolTrade-Gebundenheit** (1592/PTR) und **verfügbar** (1590/AVA).

### B) Trader-Ebene (unverändert im Zielbild, Idempotenz fix)

| Ereignis | Beleg | Kontoauszug |
|----------|-------|-------------|
| Jede `sellOrder` | `createTradeExecutionDocument` (Typ sell), **idempotent pro `sellOrderId`** | `trade_sell` (kumulativ-idempotent) |

### C) Investor-Ebene – Partial Sell (Trade noch offen)

| Ereignis | Beleg | App-Ledger (Escrow) | Kontoauszug |
|----------|-------|---------------------|-------------|
| Partial Sell | **Interner Eigenbeleg** `investorPartialSellInternal` (kein Kunden-CB) | **PTR → PPS** (`partialSellRelease`, Einstand) + **INV-PNL → PPS** (`partialSellProfitRecognition`, Brutto-Gewinn); idempotent pro `sellOrderId` | **keine** `investment_return` / keine Provision / keine Steuer |

Einstand = proportionaler **Einstand** der verkauften Pool-Stück (`buyLeg.amount`). Brutto-Gewinn = `deriveMirrorTradeBasis` der Partial-Sell-Scheibe (Provision erst bei Trade-Ende). Bei Trade-Ende: kumuliertes **PPS → AVA** (Einstand + bereits realisierter Brutto-Gewinn), Rest **INV-PNL → AVA** (Netto-Gewinn minus bereits realisierter Brutto-Partial-Gewinne).

### D) Investor-Ebene – Trade completed (Settlement)

| Ereignis | Beleg | App-Ledger | Kontoauszug |
|----------|-------|------------|-------------|
| Completion-Save (letzter Sell) | Letzter **interner** EBP + **PMSC** pro `sellOrderId` (falls noch fehlend) | Letzter Partial-Delta **PTR/PPS** wie bei offenem Trade | **keine** Kundenauszahlung |
| `settleAndDistribute` | Offizielle **Collection Bill** (extern) | Rest **PTR → AVA**; kumuliertes **PPS → AVA**; **P/L → AVA** (Gewinn) | `investment_return`, `commission_debit`, Steuern (wie bisher, mit `remainingTransfer`-Idempotenz) |

Der Completion-Save darf den internen Partial-Delta-Pfad **nicht** überspringen — nur externe Collection Bills bleiben Settlement-exklusiv.

`bookTradeSettlementPayout` berücksichtigt bereits gebuchte `partialSellRelease`-Beträge auf PTR.

### E) Investment-Felder

`applyPartialSellRealizationToInvestments` (Counters `partialSellCount`, `realizedSellAmount`, …) bleibt — nur **Buchungs-/Belegpfad** ändert sich.

### F) Trader-Provision (Provisionsgutschrift)

| Phase | Buchung / Beleg |
|-------|-----------------|
| Partial Sell (Trade offen) | **keine** `commission_credit`, **kein** Trader-Gutschrift-Beleg |
| Trade `completed` + `settleAndDistribute` | **eine** `commission_credit` + `traderCreditNote` auf Basis der **saldoierten** Pool-Mirror-Ökonomie (Summe der Investor-Collection-Bills / `deriveMirrorTradeBasis`, nicht pro Partial-Sell-Delta) |

Voraussetzungen für die Provisionsgutschrift:

1. Trader-Leg `status === completed` (Settlement-Worker nur nach Completion-Enqueue).
2. Pool-Mirror-Verkaufsökonomie ist synchronisiert; Partial-Sell-Freigaben (PTR→PPS) sind in `bookTradeSettlementPayout` saldiert.
3. Investor-`commission_debit` und Trader-`commission_credit` entstehen **gemeinsam** erst im Completion-Settlement — nicht bei `bookInvestorPartialRealizationDeltaIfAny`.

## Konsequenzen

- GoB: Beleg vor Buchung; keine vorzeitige Kundenauszahlung bei Partial Sell.
- Saldo 1592 sinkt bei jedem Partial Sell; 1593 steigt; bei Trade-Ende → 1590.
- Admin-Report / Summary kann Partial-Sell-Events weiter aus `sellOrders[]` + internen Belegen ableiten.
- Legacy: bereits gebuchte `investment_return` bei Partial Sells bleiben historisch; `remainingTransfer` bei Settlement verhindert Doppelbuchung.

## Nicht-Ziele

- Kein automatisches Repair-Script für Trade 001 Investor-Ledger in dieser Phase.
- Keine Änderung der iOS-Kontoauszug-Anzeige (serverseitige Korrektur reicht nach Refresh).
