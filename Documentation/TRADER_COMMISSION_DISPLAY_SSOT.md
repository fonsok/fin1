# Trader: Provision in „Abgeschlossene Trades“ — Anzeige-SSOT

**Status:** Mai 2026 — kanonisch für die Provisionsspalte im Trade-Überblick (`TradesOverviewView`).

**Nicht verwechseln mit:** [`ORDER_CASH_AMOUNT_SSOT.md`](ORDER_CASH_AMOUNT_SSOT.md) (Order-Cash / Stück × Brief-Kurs) oder [`BOOKING_AND_BELEG_SSOT.md`](BOOKING_AND_BELEG_SSOT.md) (Buchung & Beleg-Erzeugung).

---

## Ziel

Die Spalte **Provision** im Screen **Überblick Trades-Profit** zeigt dieselben **bereits abgerechneten** Beträge wie:

- **Kontoauszug** (`commission_credit` in der Kundentimeline)
- **Gutschrift-Beleg** (`Document` Typ `traderCreditNote`, `invoiceData`)

Es gibt **keinen** eigenen Berechnungs- oder Settlement-Pfad nur für diese Liste.

---

## Priorität (Lesen, nicht neu rechnen)

| Prio | Quelle | iOS |
|------|--------|-----|
| 1 | Dokument-Inbox / Gutschrift | `DocumentService` — `traderCreditNote` + `invoiceData` (Brutto aus Commission- + VAT-Zeilen) |
| 2 | Kontoauszugs-Timeline | `TraderAccountStatementBuilder.commissionCreditTotalsByTradeId` — `getAccountStatement(entryType: commission_credit)` (gleiche Zeilen wie Kontoauszug, kleineres Payload als Voll-Timeline) |
| 3 | Trade-Settlement (`getTradeSettlement`) | `Commission`-Klasse, `commission_credit`-Zeilen, `traderCreditNote`-Metadaten — wenn Gutschrift-Beleg fehlt |
| 4 | Lokale Credit Notes | `InvoiceService.getInvoicesForTrade` (Offline-Resilienz) |

**Orchestrierung:** `TradesOverviewCommissionCalculator.refreshCommissionCache` vor Tabellenaufbau (`TradesOverviewViewModel.rebuildTrades`).

**Delegation:** `CommissionCalculationService.fetchTraderCommissionCreditTotalsByTradeId` → Builder-Methode (DRY mit Kontoauszug).

---

## Verboten in der Listen-Spalte

- `grossProfit × commissionRate` oder andere **Neuberechnung** nach Trade-Abschluss
- Pro-Zeile `getTradeSettlement` / gefilterte Settlement-API nur für Provision
- Zweite „Wahrheit“ neben Backend-Timeline und persistiertem Beleg

Buchung und Provisions-Erzeugung bleiben **Parse Cloud** (`settleCompletedTrade`, Credit Note, `AccountStatement`). Siehe [`ACCOUNT_STATEMENT_ARCHITECTURE.md`](ACCOUNT_STATEMENT_ARCHITECTURE.md).

---

## UI-Verhalten

| Zustand | Anzeige |
|---------|---------|
| Gewinn-Trade, Betrag bekannt | Formatierter EUR-Betrag (z. B. `417,87 €`) |
| Gewinn-Trade, Cache noch leer | `…` (`TradeOverviewItem.isCommissionPending`) |
| Verlust / keine Provision | `-` |
| Aktiver Trade | Status-Detail (wie bisher) |

**Inbox vor erstem Rebuild:** `TradesOverviewViewModel.primeTraderDocumentInbox()` über `UncheckedDocumentServiceBridge.loadDocuments` (Swift-6-konform, kein `DocumentService`-Cast).

**Nachladen (primär):** Notifications — `.commissionSettled`, `.userDocumentInboxShouldRefresh`, `invoiceDidChange` (Credit Note) → `rebuildTrades`.

**Nachladen (Fallback):** Einmaliger deferred Refresh nach 2 s (`scheduleDeferredCommissionRefreshIfNeeded`), nur wenn Gewinn-Trades nach erstem Cache noch ohne Betrag sind — kein Polling.

---

## Relevante Dateien

| Datei | Rolle |
|-------|-------|
| `FIN1/Features/Trader/ViewModels/TradesOverview/TradesOverviewCommissionCalculator.swift` | Cache + Priorität |
| `FIN1/Features/Trader/ViewModels/TradesOverviewViewModel+Rebuild.swift` | `refreshCommissionCache` vor `processTrades` |
| `FIN1/Shared/Accounting/TraderAccountStatementBuilder+Backend.swift` | `commissionCreditTotalsByTradeId` |
| `FIN1/Features/Trader/Views/Components/TradesTableComponents.swift` | Spalte „Provision“ |
| `FIN1/Features/Investor/Services/UncheckedDocumentServiceBridges.swift` | `loadDocuments` für Trade-Überblick |
| `FIN1/Features/Trader/ViewModels/TradesOverview/TradesOverviewCommissionCalculator.swift` | `TradesOverviewCommissionAmounts` (Parsing + `isCommissionPending`) |
| `FIN1/Features/Trader/Services/TraderCommissionSettlementResolver.swift` | `getTradeSettlement` → Trader-Provision |

---

## Tests

- `FIN1Tests/TradesOverviewCommissionCalculatorTests.swift` — Priorität Beleg vs. Timeline, `grossCommission`, `isCommissionPending`, kein Lookup bei Verlust

---

## Abnahme (kurz)

1. Abgeschlossener Gewinn-Trade: Provision in Trade-Überblick = Kontoauszug-Zeile `commission_credit` = Gutschrift-Beleg-Brutto.
2. Nach Inbox-Refresh / Settlement-Notification: Spalte aktualisiert ohne App-Neustart.
3. Verlust-Trade: `-`, kein `…`.
