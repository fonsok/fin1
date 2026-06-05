# iOS: Trader Collection Bill — Beleg-SSOT

**Status:** Phase 1–3 umgesetzt (Snapshot + Cloud-Enrichment + Vergleichs-Hinweis).

**Backend-SSOT:** `traderCollectionBillBelegSnapshot.js` → `Document.metadata` + `accountingSummaryText` auf Parse.

## Zielbild

| Priorität | Quelle | Wann |
|-----------|--------|------|
| 1 | `Document.accountingSummaryText` (Parse) | Neue TBC/TSC |
| 2 | `getTraderDocumentBelegDetail` (Session) | Alt-Belege ohne Parse-Text |
| 3 | `TradeStatementView` + `Invoice` | Nur Vergleich / fehlender Beleg |

## Phase 1 ✅

- `TraderCollectionBillBelegSnapshotView` — Klartext-Beleg
- `CollectionBillDocumentView` routet Snapshot vor `TradeStatementView`

## Phase 2 ✅

- Cloud: `getTraderDocumentBelegDetail` (`functions/documents/traderBelegDetail.js`)
  - Session-only, nur eigene `Document.userId`
  - `enrichTraderDocumentMetadata` + `projectDocumentDetail`
- iOS: `DocumentAPIService.fetchTraderBelegDetail` → `DocumentService.fetchTraderBelegDetailEnriched`
- `CollectionBillDocumentViewModel+BelegSnapshot` ruft Cloud-Funktion auf, wenn Parse-Text fehlt

## Phase 3 ✅

- Link „Abrechnung aus Rechnung“ setzt `isInvoiceComparisonMode`
- `TradeStatementView` zeigt orangenen Hinweis-Banner

## Offen (optional)

- Admin-Backfill: `accountingSummaryText` auf Alt-`Document`-Rows persistieren
- Strukturierte `displaySections` auf iOS decodieren
- Automatischer Drift-Check Snapshot vs. Invoice-Beträge

## Abnahme

1. Neuer TBC: Snapshot aus Parse ohne Cloud-Call.
2. Alter TBC ohne Text: nach Login Snapshot via `getTraderDocumentBelegDetail`.
3. Rechnungsdetail: Banner sichtbar, Inhalt aus Invoice.
