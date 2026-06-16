# ADR-018 – P3c: Monetary Cent-Integer at Booking Boundaries

- **Status:** Accepted (P3c-0 implemented 2026-06-15)
- **Datum:** 2026-06-15
- **Bezug:** GoB **P3a** (keine Client-Invoice-Synthese in Prod), **P3b** (`InvoiceLocalSynthesisGate`), [`BOOKING_AND_BELEG_SSOT.md`](BOOKING_AND_BELEG_SSOT.md), [`ADR-010-Settlement-GL-Posting.md`](ADR-010-Settlement-GL-Posting.md), [`ADR-017-Settlement-Dual-Write-Outbox-And-Core-Ledger.md`](ADR-017-Settlement-Dual-Write-Outbox-And-Core-Ledger.md), [`ADR-009-iOS-Reads-Server-BuyLeg-SellLeg.md`](ADR-009-iOS-Reads-Server-BuyLeg-SellLeg.md)

## Kontext

### Was P3a/P3b bereits sichern (Voraussetzung)

| Phase | Ziel | Effekt für Numerik |
|-------|------|-------------------|
| **P3a** | `blocksInvoiceSynthesis` / server-only Trade-Statement | Prod-Anzeige liest Beleg-SSOT, kein Swift-Neurechnen aus `Trade`/`Order` |
| **P3b** | `InvoiceLocalSynthesisGate` | `InvoiceFactory.from` nur Tests/Dev — keine parallele Geld-Pipeline auf dem Client |
| **Beleg-SSOT** | Trader TBC/TSC + Drift-Guard | Buchungsbeträge kommen aus einem Snapshot-Lauf; Teilverkauf-Leg-Drift erkennbar |

**P3c löst ein anderes Problem:** nicht *wo* gerechnet wird, sondern *mit welcher Numerik* an den **Buchungsgrenzen**.

### Ist-Zustand (technisch)

- **Backend:** JavaScript `Number` + `round2()` (`Math.round(n * 100) / 100`) in ~50 Modulen unter `utils/accountingHelper/`.
- **Gebühren:** Prozent × Kurswert in `helpers.js::calculateOrderFees` (Float-Multiplikation, dann Cent-Rundung).
- **Kundensaldo:** Mongo `$inc` auf `UserCashBalance.currentBalance` mit Float (`userCashBalanceAtomic.js`).
- **GL:** `journal.js::postLedgerPair` — Soll/Haben aus demselben `round2`-Betrag (gut, aber Float-Eingang).
- **Toleranzen:** 2 ct (`TOLERANCE = 0.02`) in Beleg-Invarianten; 0,5 ct Ketten-Guard (`accountStatementChainGuard.js`).
- **iOS:** `Double` in Modellen (`TraderCollectionBillBelegMetadata`, `Investment`, `Invoice`, …).
- **Parse/Mongo:** numerische Felder als JSON-Number (EUR, 2 Nachkommastellen **konventionell**, nicht erzwungen).

### Risiken ohne P3c

1. **Kumulative Float-Fehler** bei `$inc` + wiederholten Teil-Verkäufen / Multi-Investor-Splits.
2. **Heuristische Toleranzen** (2 ct) maskieren echte Drift statt sie an der Quelle zu verhindern.
3. **Zwei Rundungswelten** (Backend `round2`, iOS `Double`, Drift-Monitore) — ops-intensiv.
4. **Teilverkauf / Leg-Matching** (vgl. TSC-141): fehlerhafte Metadaten entstehen leichter, wenn Eingänge nicht cent-normalisiert sind.

### Warum jetzt sinnvoll

Server-APIs und Trader-Anzeige-Pipeline sind **stabil genug**, dass P3c an **festen Grenzen** ansetzen kann, ohne parallel Client-Synthese-Pfade zu migrieren. Investor-Collection-Bill-SSOT (ADR-009) kann **parallel** reifen; P3c-1 trifft zuerst den **Settlement-Schreibpfad**, nicht alle Beleg-Builder.

---

## Entscheidung

### Grundsatz

1. **Intern (Buchungskern):** Geldbeträge ab der Normalisierungsgrenze als **Integer Cent** (`EUR`, Faktor 100).
2. **Persistenz (Übergang):** Parse/Mongo-Felder bleiben vorerst **Number in EUR** — aber nur Werte, die **cent-aligned** sind (Vielfaches von 0,01).
3. **API / Beleg-Metadaten (Übergang):** JSON-Number EUR mit **Cent-Validierung** beim Schreiben; optional später `amountCents` in Schema v2.
4. **iOS (P3c-3):** `Decimal` **nur** für Decode + Anzeige/Format — **keine** Buchungsentscheidungen auf dem Client in Prod.
5. **Kein Big-Bang:** `round2()` bleibt als Kompatibilitäts-Fassade; Implementierung delegiert schrittweise an `moneyCents`.

### Nicht gewählt (bewusst)

| Alternative | Warum nicht (jetzt) |
|-------------|---------------------|
| `decimal.js` / BigDecimal überall | Schwere Migration; Cent reicht für EUR-GoB |
| Sofort `Decimal128` in Mongo | Schema-/Backfill-Aufwand ohne Booking-Gewinn |
| iOS-first Migration | Buchungs-SSOT liegt auf dem Server |
| Alles auf einmal auf Cent | Risiko; phasenweise mit Tests + Monitoren |

---

## SSOT-Modul: `moneyCents.js` (neu)

**Pfad:** `backend/parse-server/cloud/utils/accountingHelper/moneyCents.js`

**Verantwortung:** Einzige Stelle für EUR↔Cent, Addition, Vergleich, Cent-Ausrichtung.

### API (Vorschlag)

```javascript
// Normalisierung
euroToCents(euro)           // → safe integer; wirft bei >2 Nachkommastellen / non-finite
centsToEuro(cents)          // → Number, immer .xx
fromEuroNumber(n)           // alias mit Fail-closed

// Arithmetik (integer only)
addCents(a, b)
subtractCents(a, b)
multiplyEuroByRatio(euro, ratio) // z. B. Provision % — ein Rundungsschritt am Ende

// Vergleich / Guard
centsEqual(a, b)
withinCentsTolerance(centsA, centsB, toleranceCents = 0)
assertCentAlignedEuro(euro, context)

// Kompatibilität
round2Euro(euro)            // euroToCents → centsToEuro (ersetzt langfristig shared.round2)
```

### Rundungsregel (SSOT)

- **Half-up auf Cent** — identisch zum heutigen `Math.round(n * 100) / 100` für positive Beträge.
- **Währung:** nur **EUR**; Erweiterung multi-currency = neues ADR.
- **Gebühren-Prozent:** `multiplyEuroByRatio` rundet **einmal** nach Multiplikation; Min/Max-Clamps in Cent-Raum (wie heute, aber ohne Float-Zwischenwerte wo vermeidbar).

### Toleranz-Mapping

| Heute | P3c |
|-------|-----|
| `TOLERANCE = 0.02` (Beleg) | `toleranceCents = 2` |
| `FLOAT_TOLERANCE = 0.005` (Kette) | `toleranceCents = 1` (0,5 ct → explizit dokumentieren oder 1 ct wählen) |

Drift-Monitore bleiben; Ziel ist **weniger** Drift-Ereignisse, nicht weniger Monitore.

---

## Wire-Format (API & Beleg — P3c-2)

### Phase Übergang (empfohlen)

| Schicht | Format | Regel |
|---------|--------|-------|
| **Parse-Felder** | `Number` EUR | Schreibpfad nur via `centsToEuro(euroToCents(x))` |
| **Cloud Function JSON** | `Number` EUR | Ingress-Validierung: cent-aligned oder 400 |
| **Beleg `metadata` v1** | `amount`, `totalWithFees`, `fees.*` als Number | unverändert; Werte cent-normalisiert |
| **Beleg `metadata` v2** (später) | optional `amountCents: Int` | Dual-Write + Drift-Guard; iOS liest bevorzugt Cents |

### iOS Decode (P3c-3)

```swift
// Anzeige-DTO — kein Booking
let amount: Decimal  // decode from JSON Number oder String "2400.00"
```

- **Kein** `Double`-Recalc für Fees/Profit in Prod (`investorMonetaryServerOnly` / `traderMonetaryServerOnly`).
- Formatter bleiben in `Number+Formatting.swift`; Eingabe ist `Decimal`.

---

## Phasen-Roadmap

| Phase | Inhalt | Done when |
|-------|--------|-----------|
| **P3c-0** | Dieses ADR + `moneyCents.js` + Unit-Tests | Tests grün; `round2Euro` ≡ `round2` für Referenzvektor |
| **P3c-1** | Settlement-**Schreibpfad** (5 Dateien unten) | GL-Pair immer cent-gleich; `$inc` nur cent-aligned |
| **P3c-1b** | `calculateOrderFees`, Beleg-Snapshots (`collectionBill*`, `traderCollectionBill*`) | Snapshot-Invarianten in Cent; `assertNear` nutzt `withinCentsTolerance` |
| **P3c-2** | API-Ingress + optional `amountCents` in neuer Schema-Version | Drift-Monitor: non-cent-aligned writes = 0 |
| **P3c-3** | iOS Anzeige-DTOs (`Decimal`) | Trader + Investor Beleg-Detail ohne `Double`-Geldfelder in SSOT-Pfad |
| **P3c-4** | Optional: `UserCashBalance.currentBalanceCents` | Migrations-Backfill; EUR-Feld deprecated |

**Abhängigkeit:** P3c-1 **blockiert nicht** auf ADR-009 Investor-Leg-Read; umgekehrt soll Investor-SSOT keine neuen Client-Recalc-Pfade einführen.

---

## P3c-1 — Erste 5 Dateien (Settlement-Schreibpfad)

Reihenfolge der Implementierung:

### 1. `utils/accountingHelper/moneyCents.js` *(neu)*

- SSOT für Cent-Arithmetik.
- Tests: `0.1 + 0.2`, Fee-Min/Max, negative Beträge (Storno), große Summen (< `Number.MAX_SAFE_INTEGER` Cent).

### 2. `utils/accountingHelper/shared.js`

- `round2()` delegiert an `moneyCents.round2Euro()` (verhalten identisch — **kein** Semantik-Bruch).
- Export `TOLERANCE_CENTS = 2` neben legacy `round2` für schrittweise Caller-Migration.

**Warum:** Alle bestehenden `require('./shared')`-Imports profitieren sofort von zentraler Normalisierung, ohne 50 Dateien anzufassen.

### 3. `utils/accountingHelper/journal.js`

- `postLedgerPair`: `amount` → `euroToCents` → `centsToEuro` für **beide** Seiten aus **demselben** Cent-Wert.
- Garantie: `debit.amount === credit.amount` bit-identisch in Parse.

**Warum:** GL ist die härteste Doppelbuchungs-Invariante (ADR-010).

### 4. `utils/accountingHelper/userCashBalanceAtomic.js`

- `advanceUserCashBalanceAtomic` / `compensateUserCashBalanceAdvance`: `$inc` nur mit `centsToEuro(euroToCents(amount))`.
- `balanceBefore` / `balanceAfter` aus Cent-Raum berechnen, dann EUR zurück.

**Warum:** Mongo `$inc` mit Ro-Float ist die wahrscheinlichste Quelle für Kunden-Saldo-Drift (Phase 3b).

### 5. `utils/accountingHelper/accountStatementWriter.js`

- `bookAccountStatementEntry`: `amount`, `balanceBefore`, `balanceAfter` vor `save` cent-normalisieren.
- Audit-Logs optional mit `amountCents` (structuredLogger).

**Warum:** Personenkonto ist Kundensaldo-SSOT; GL hängt an `bookSettlementEntry` → Statement zuerst sauber.

### Bewusst **nicht** in P3c-1

| Modul | Phase | Grund |
|-------|-------|-------|
| `collectionBillBelegSnapshot.js` | P3c-1b | Beleg-SSOT; hängt an Fee-Engine |
| `traderCollectionBillBelegSnapshot/*` | P3c-1b | bereits stabil; Migration nach Cash/GL |
| `helpers.js::calculateOrderFees` | P3c-1b | viele Caller; nach `moneyCents` stabil |
| iOS Modelle | P3c-3 | Anzeige-only; kein Booking-Risiko wenn Server-only |
| Parse Schema Migration | P3c-4 | optional |

---

## P3c-1 — Akzeptanzkriterien

1. **`moneyCents.test.js`:** Referenzvektor ≥ 30 Fälle (Fees, Steuer, negative Buchungen, Teilsummen).
2. **`journal.test.js`:** Pair-Amounts immer identisch; Cent-Alignment für `0.1 + 0.2`-Eingänge.
3. **`userCashBalanceAtomic` Tests:** `$inc` cent-normalisiert; `balanceAfter` aus Cent-Raum.
4. **Kein Prod-Verhalten-Bruch:** bestehende `round2`-Tests grün; `accountStatementChainGuard` weiter grün.
5. **Deploy:** Parse Cloud only; **kein** iOS-Release nötig für P3c-1.

**Status P3c-1:** Implemented 2026-06-15 (`journal.js`, `userCashBalanceAtomic.js`, `accountStatementWriter.js`).

**Status P3c-1b:** Implemented 2026-06-16 (`helpers.js::calculateOrderFees`, `collectionBillBelegSnapshot.js`, `traderCollectionBillBelegSnapshot/*` invariants via `withinCentsTolerance`).

---

## Ops & Drift

- Bestehende Monitore (`checkTraderCollectionBillBelegDrift`, Settlement-GL-Reconciliation, Chain-Verify) **bleiben**.
- Optional **P3c-1 follow-up:** Cloud-Health-Check `nonCentAlignedMonetaryWrites` (Audit-Stichprobe auf letzte N `AccountStatement`-Zeilen) — nicht Blocker für P3c-1 Start.
- Repair unverändert: `backfillTraderCollectionBillBeleg` / Settlement-Repair; nach P3c-1b Backfills cent-normalisieren.

---

## Konsequenzen

**Positiv**

- Buchungsgrenzen werden deterministisch; `$inc`/GL-Pairs robuster.
- Klare Migration ohne Client-Big-Bang.
- `round2`-Kompatibilität schützt bestehende Tests und Ops-Playbooks.

**Negativ / Akzeptiert**

- Übergangsphase: intern Cent, extern EUR-Number — Disziplin am Schreibpfad nötig.
- Investor-Beleg-Pipeline noch `Double` bis P3c-1b/3 — mit server-only akzeptabel.
- Ein ADR ersetzt keine automatische Durchsetzung — Code-Review + Tests pro Phase.

---

## Nicht-Ziele

- Vollständige Entfernung von `Number` in Parse in 2026.
- Postgres-/Core-Ledger-Migration (ADR-017 Trigger unverändert).
- Steuer-/Provisions-**Fachlogik** ändern — nur Numerik-Träger.
- `frontendReadonlyMode` in Prod aktivieren (weiterhin redundant zu monetary server-only).

---

## Referenzen (Implementierung)

| Thema | Pfad |
|-------|------|
| Cent-SSOT (neu) | `utils/accountingHelper/moneyCents.js` |
| Legacy-Rundung | `utils/accountingHelper/shared.js` |
| GL-Pair | `utils/accountingHelper/journal.js` |
| Atomischer Saldo | `utils/accountingHelper/userCashBalanceAtomic.js` |
| Personenkonto | `utils/accountingHelper/accountStatementWriter.js` |
| Settlement-Wrapper | `utils/accountingHelper/settlementGLPoster.js` |
| Gebühren (P3c-1b) | `utils/helpers.js::calculateOrderFees` |
| Beleg Invarianten | `collectionBillBelegSnapshot.js`, `traderCollectionBillBelegSnapshot/` |
| iOS Gate P3b | `FIN1/Shared/Services/InvoiceLocalSynthesisGate.swift` |
| iOS Beleg DTO | `FIN1/Shared/Models/TraderCollectionBillBelegMetadata.swift` |

---

## Nächster Schritt (nach Acceptance dieses ADR)

1. Review ADR-018 (Stakeholder: Finance/Ops + Backend).
2. **P3c-0 implementieren:** `moneyCents.js` + Tests, `shared.js`-Delegation.
3. **P3c-1:** Dateien 3→5 in oben genannter Reihenfolge, je ein PR oder ein fokussierter Commit-Block mit Deploy + Smoke.
