# ADR-012 – Teil-Sell-Kennzahlen (iOS), Finance-Consistency-Smoke & Admin-System-Health

- **Status:** Accepted  
- **Datum:** 2026-05-02  
- **Bezug:** `ADR-010-Settlement-GL-Posting.md`, `ADR-011-Trustee-Bank-And-Trade-GL.md`, `INVESTMENT_ESCROW_LEDGER_SKETCH.md`

## Kontext

1. **Teil-Verkäufe (Trade):** Investoren erhalten pro Teil-Sell-Ereignis Buchungen/Belege (`bookInvestorPartialRealizationDeltaIfAny` in `settlement.js`); `Investment` wird in `triggers/trade.js` (`applyPartialSellRealizationToInvestments`) um Kumulativwerte ergänzt (`partialSellCount`, `realizedSellQuantity`, `realizedSellAmount`, `lastPartialSellAt`).
2. **Verwechslungsrisiko UI:** Der Quotient **„realizedSellAmount / investment.amount“** ist **nicht** gleichbedeutend mit **„verkaufte Stück / gekaufte Stück“** am Trade: Er beschreibt den auf den Investor umgelegten **Brutto-Verkaufserlös** relativ zur **Einlage**. Bei proportionalem Pool (z. B. 1.000 € + 2.000 € = 3.000 €) ist dieser Prozentsatz für alle Beteiligten **numerisch gleich**, wenn der Erlös anteilig verteilt wird — während der **Stück-Fortschritt** am Trade (z. B. 200/1.000 = 20 %) für alle gleich ist, aber **anders** interpretiert werden muss.
3. **iOS-Sync:** `InvestmentService.fetchFromBackend` muss Teil-Sell-Felder (und spätere Server-Felder) beim Merge **nicht verwerfen**; `InvestmentCompletionService` darf sie bei Profit-Updates **durchreichen**.
4. **Betrieb:** Admin-Portal **System**-Seite soll nach Host-Reboot keine falschen **„Systemausfälle“** melden, wenn nur der Health-Request fehlschlägt oder MongoDB-Health zu streng prüft.
5. **Finance-QA:** Operative Konsistenzprüfungen (Settlement vs. `AccountStatement`, Ledger-Fuzzy, Beleg-Referenzen) sollen **zentral** aufrufbar sein.

## Entscheidung

### A) Parse-Feld `tradeSellVolumeProgress` (Investment)

- Beim Update durch `applyPartialSellRealizationToInvestments`:  
  `tradeSellVolumeProgress = min(1, totalSellQuantity(trade) / buyQuantity)` (kumulativ, gleicher Wert für alle `PoolTradeParticipation` eines Trades).
- **Semantik:** Anteil der **am Trade verkauften Stückzahl** an der **Kaufmenge** — entspricht der Nutzererwartung „20 % bei 200 von 1000“.

### B) iOS-Anzeige

- Zwei Kennlinien in **Teil-Sell-Details** / Liste:
  - **„Trade (Stück, kumulativ): … %“** aus `tradeSellVolumeProgress` (falls gesetzt; ältere Daten ohne Feld: nur zweite Zeile).
  - **„Bruttoerlös / Einlage: … %“** = bisherige `realizedSellAmount / amount` mit klarer Benennung.
- Kurzer Hinweistext, dass der Brutto-Quotient bei Gewinn **über** dem reinen Stück-Anteil liegen kann.

### C) Finance-Consistency & Settlement-Checks (Cloud)

- **`getTradeSettlementConsistencyStatus`:** Vergleich erwarteter vs. gebuchter Summen für abgeschlossene Trades (Performance: Batch-Abfragen).
- **`runFinanceConsistencySmoke`:** Orchestriert Mirror-Basis, Settlement-Status, Ledger-Fuzzy-Smoke, Referenz-/Beleg-Coverage (Stichprobe).
- **`benchmarkTradeSettlementConsistency*` (optional):** synthetisch/live zur Messung — nicht für Endnutzer-Pflichtpfad.

### D) Admin-Portal System-Health

- **`getSystemHealth`:** MongoDB bleibt **verbunden**, wenn nur der optionale Voll-`_SCHEMA`-Scan fehlschlägt; Verbindung wird über `limit(1)` auf `_SCHEMA` belegt.
- **Frontend:** Transport-/Auth-Fehler beim Laden → `overall: unknown` + Fehlermeldung, **nicht** automatisch `down` („Systemausfall“).
- **React Query:** `getSystemHealth` mit **Retries** und exponentiellem Backoff (Boot-Fenster nach Ubuntu-Start).

### E) App Ledger (Admin)

- **Summen** der Übersichtskarten und **totalCount** kommen aus **serverseitiger Aggregation** (nicht aus der aktuellen Seite der Tabelle).
- **User-Filter:** Nur bei Parse-ObjectId-ähnlicher Eingabe striktes `equalTo('userId')`; sonst breitere Abfrage + **fuzzy** Filter über mehrere Nutzer-Felder (z. B. E-Mail, Username).

## Konsequenzen

- **Dokumentation / Schulung:** Buchhaltung und Support müssen **Bruttoerlös/Einlage** vs. **Trade-Stück** unterscheiden können (siehe `11_APP_LEDGER_BUCHHALTER_MANUAL.md` für Ledger-Oberfläche).
- **Deploy:** Nach Änderungen an `cloud/triggers/trade.js` bzw. `functions/admin/opsHealth.js` / `reports/appLedger.js` / `functions/admin/system.js` übliches **Cloud-Code rsync + parse-server restart**; Admin-Portal separat **`admin-portal/./deploy.sh`**.

## Nicht-Ziele

- Keine Änderung der **buchhalterischen** Teil-Sell-Logik (Delta-Buchungen, Belegkette) — nur Transparenz in Kennzahlen und Ops-Transparenz.
