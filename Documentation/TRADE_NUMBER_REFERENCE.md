# Trade-Nummer — Referenz (SSOT)

**Stand:** 2026-06-30  
**Zielgruppe:** Entwicklung, Admin-Portal, Support, KI/FAQ

---

## Kurzfassung

| Aspekt | Regel |
|--------|--------|
| **Anzeige** | `YYYY-NNN` (z. B. `2026-001`) |
| **Zeitzone** | `Europe/Berlin` (Kalenderjahr) |
| **Scope** | Pro **Trader**, Sequenz startet jedes Jahr bei `001` |
| **SSOT Vergabe** | Parse Server (`SequenceCounter`, race-safe) |
| **Persistenz** | `Trade.tradeNumber` (Int) + `Trade.tradeNumberYear` (Int) |
| **Unique** | Compound-Index `(traderId, tradeNumberYear, tradeNumber)` |

Die **interne** `tradeId` (Parse `objectId`) bleibt für Buchungen und Verknüpfungen maßgeblich; die Trade-Nummer ist die **menschenlesbare Referenz**.

---

## Format

- **Display:** `2026-001` — Jahr, Bindestrich, dreistellige Sequenz (ohne Obergrenze im Code; UI formatiert mit `%03d`).
- **Label:** `Trade #2026-001`
- **API businessReference (Kontoauszug):** `TRD-2026-001`
- **Beleg-Dateiname (Token):** `Trade2026-001` (z. B. `CreditNote_Trade2026-001_20260630_ABC12.pdf`)

Legacy-Dateinamen (`Trade14`, `Trade001`) werden beim Parsen weiter unterstützt; neue Belege nutzen das Jahr-Format.

---

## Vergabe (Backend)

**Modul:** `backend/parse-server/cloud/utils/tradeNumberAllocation.js`

1. Kalenderjahr aus `createdAt` (oder Referenzdatum) in Europe/Berlin → `tradeNumberYear`.
2. `SequenceCounter`-Key: `Trade::tradeNumber::{traderId}::{year}`.
3. Seed beim ersten Counter: höchste bestehende `tradeNumber` für `(traderId, tradeNumberYear)`.
4. Atomisches Increment wie bei Order-/Ticket-Nummern (`allocateSequentialCounter` in `helpers.js`).

**Einstiegspunkte:**

- `tradingUpsertTrade` — neue Trades: Server vergibt immer (Client-`tradeNumber` wird ignoriert).
- `tradeTriggerBeforeSave` — Fallback, wenn `(tradeNumber, tradeNumberYear)` noch nicht autoritativ gesetzt.
- Schema-Migration `trade_number_year_v1` — Backfill `tradeNumberYear` aus `createdAt`.

**Hilfs-API:**

- `formatTradeNumberForDisplay(number, year)`
- `formatTradeNumberLabel(number, year)` → `Trade #2026-001`
- `resolveTradeNumberPresentation(trade)` → `{ tradeNumber, tradeNumberYear, formattedTradeNumber, filenameToken, label }`

**Client-API:** `normalizeTradeForClient` setzt zusätzlich `formattedTradeNumber` auf Trade-JSON.

---

## iOS

| Komponente | Rolle |
|------------|--------|
| `TradeNumberFormatting.swift` | Zentrale Anzeige (`display`, `labeled`, `filenameToken`, `calendarYear`) |
| `Trade.tradeNumber` / `tradeNumberYear` | Persistierte Felder; `resolvedTradeNumberYear` / `formattedTradeNumber` |
| `TradeNumberService` | **Cache/Sync nur** — Parse ist SSOT; keine lokale Pre-Vergabe beim Trade-Create |
| Lookups | Year-aware: `TradeDetailsRoute`, `CollectionBillByNumberViewModel`, `CollectionBillDocumentViewModel+TradeResolution` |

---

## Admin-Portal

**Spezifikation:** `FIN1_APP_DOCS/10_ADMIN_PORTAL_REQUIREMENTS.md` — Anzeige als `YYYY-NNN`.

**Implementierung:** `admin-portal/src/utils/tradeNumberFormat.ts` (`formatTradeNumber`, `formatTradeNumberHash`, `formatTradeNumberLabel`). UI-Komponenten nutzen `tradeNumberYear` aus der API mit Fallback auf Kalenderjahr (Europe/Berlin) aus `createdAt`/`completedAt`. Backend liefert `tradeNumberYear` u. a. in User-Detail, Summary Report und Collection-Bill-Summaries.

---

## Suche & Kontoauszug

- **Admin-List-Suche:** `adminSearchBlob` enthält Trade-Nr.; reine Ziffern → Equality auf `tradeNumber`; Volltext findet auch `2026-001` im Blob. Siehe `ADMIN_LIST_SEARCH.md`.
- **Trader-Kontoauszug (Kundensicht):** `traderAccountStatementPresentation` — Events mit `tradeNumberYear`; Dedup-Keys `num:{year}:{number}` plus Legacy `num:{number}`. Siehe `ACCOUNT_STATEMENT_ARCHITECTURE.md`.

---

## Abgrenzung zu anderen Nummern

| Begriff | Bedeutung | Beispiel |
|---------|-----------|----------|
| **Trade-Nummer** | Menschliche Trade-Referenz pro Trader/Jahr | `2026-001` |
| **Belegnummer** | GoB-Dokument (`accountingDocumentNumber`) | `CN-2026-0000042` |
| **Kunden-ID TRD-…** | Trader-**Kundennummer** (Identität), nicht Trade | `TRD-2026-00001` — siehe `IDENTITIES.md` |

---

## Tests & Deploy

- Unit: `cloud/utils/__tests__/tradeNumberAllocation.test.js`
- Nach Backend-Änderungen: `./scripts/deploy-parse-cloud-to-fin1-server.sh` (vgl. `ci-cd.md`)

---

## Verwandte Dokumente

- `BOOKING_AND_BELEG_SSOT.md` — Belege & Buchungen
- `BELEGNUMMERN_FINAL_SUMMARY.md` — Belegnummern (CN/TBC/…)
- `ACCOUNT_STATEMENT_ARCHITECTURE.md` — Kontoauszug-Pipeline
- `FIN1_APP_DOCS/12_PRODUKT_MERKMALE_KI_FAQ.md` — FAQ-Antwort Trade-Nummer

**Veraltet (nur historisch):** `FIN1/Documentation/Archive/.../TRADE_NUMBERING_IMPLEMENTATION_SUMMARY.md` (Modell ohne Jahres-Reset).
