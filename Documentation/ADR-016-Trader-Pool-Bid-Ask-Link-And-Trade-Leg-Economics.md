# ADR-016 – Trader↔Pool: nur Bid/Ask, Domain `tradeLegEconomics`

- **Status:** Accepted
- **Datum:** 2026-06-09
- **Bezug:** `ADR-014`, `legPriceMetrics.js`, `poolMirrorEconomics/`

## Problem

1. Pool-Mirror-Report zeigte Trader-Einstand/Gebühren (z. B. 1.000-Stück-Order auf 797 Pool-Stück).
2. Verkaufsgebühren wurden teils auf Pool-Gesamt-Brutto statt pro Pool-Sell-Order berechnet.
3. `tradeEconomicsSnapshot` lag im Report-Modul — keine Domain-SSOT.

## Entscheidung

### A) Verknüpfung Trader ↔ Pool-Mirror

| Seite | Einzige gemeinsame Größe | Pool rechnet selbst |
|-------|--------------------------|---------------------|
| **Kauf** | **Bid** (nominell/Stück) | Stück, Brutto, Gebühren, Einstand, Pool-Einlage |
| **Verkauf** | **Ask** je Sell-Order | Pool-Δ-Stück, Brutto, Gebühren, Netto, P/L |

Nicht kopieren: Trader-`costBasisPerShare`, `buyFeesTotal`, `totalBuyCost`, Verkaufsgebühren, Nettoerlös.

### B) Domain-SSOT `tradeLegEconomics.js`

- Pfad: `backend/parse-server/cloud/utils/poolMirrorEconomics/tradeLegEconomics.js`
- Export: `tradeEconomicsSnapshot` (Tier-1 über `poolMirrorEconomics` Fassade)
- Report: `summaryReportTradeSnapshot.js` = dünner Re-Export (Abwärtskompatibilität)

### C) Pool-Kauf / Pool-Verkauf

- Kauf: `resolvePoolMirrorBuyMetricsFromBid({ poolPieces, bidPricePerShare, feeConfig })`
- Verkauf SSOT: `enumeratePoolSellEventsFromTraderOrders` — je Trader-Sell-Order Pool-Δ, Brutto, Gebühren, Netto
- Aggregation: `aggregatePoolSellFromTraderSellOrders` = Summe über Enumeration
- Report Partial-Sell: `buildPartialSellEvents` nutzt dieselbe Enumeration (kein paralleler Sell-Pfad)

### D) P/L

- Trader offen: `−totalBuyCost`
- Trader verkauft: `netto − (verkaufte Stück × round2(Einstand))`
- Pool offen: `−poolCapitalAllocated`
- Pool verkauft: Pool-Netto − (Pool-Stück × Pool-Einstand)

## Regression-Anchor (E2E)

`poolMirrorEconomics/__tests__/tradeLegEconomicsE2e.test.js` — GS4GLEF Szenario:

| Leg | Kennzahl | Wert |
|-----|----------|------|
| Trader | Stück / Kaufvolumen | 1.000 / 3.761,70 € |
| Trader | Einstand | 3,7617 € |
| Pool | Stück / Einlage / Residual | 797 / 2.996,72 € / 3,28 € |
| Pool | Einstand / Gebühren (Kauf) | 3,7625 € / 17,90 € |
| Sell | Trader 200 @ 3,74 → Pool 159 Stück | Brutto 594,66 €, Netto 586,66 € |

## Konsequenzen

- Summary Report importiert Domain, keine Gebührenformeln im Report.
- Phase 2 (Snapshot-Dedup im Report) und Phase 3 (persistierte Economics) bauen auf dieser Domain auf.

## Phase 3–4 (Perfektions-Roadmap)

| Phase | Status | Inhalt |
|-------|--------|--------|
| **3.1–3.3** | Done | `Trade.legEconomicsSnapshot` Write-Path; Report Snapshot-first; Mongo-Return-Filter auf `legEconomicsSnapshot.returnPercentage` |
| **4.1** | Done | `getTraderPoolBidAskContractStatus` — erkennt kopierten Trader-Einstand/Gebühren bei unterschiedlicher Stückzahl |
| **4.2** | Done | `benchmarkSummaryReportTradesPage` — Performance-Baseline (100 Zeilen, Cron-Monitor) |
| **4.3** | Done | `ENGINEERING_GUIDE.md` — Bid/Ask-only-Verknüpfung dokumentiert |
