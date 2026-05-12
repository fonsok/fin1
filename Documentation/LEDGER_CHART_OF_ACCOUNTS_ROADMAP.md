# Ledger Chart-of-Accounts Roadmap (GoB/DATEV-ready)

## Ziel

FIN1 soll von rein internen Ledger-Konten (`PLT-*`, `CLT-*`, `BANK-*`) auf ein revisionssicheres Mapping-Modell erweitert werden:

- stabiles technisches Konto (`internalAccountId`)
- externes Buchhaltungskonto (`externalAccountNumber`, z. B. SKR03 `1576`)
- kontenrahmen-/mandantenfähige Zuordnung (SKR03/SKR04)
- steuerliche Steuerung über Schlüssel/Regeln statt Freitext
- historisierte, reproduzierbare Buchungszuordnung

Das Ziel ist GoB-nahe Nachvollziehbarkeit, DATEV-Exportfähigkeit und bessere Auswertbarkeit in Cost/Performance Accounting.

---

## Leitprinzipien (Architektur & Effizienz)

1. **Backend Source of Truth**  
   Kontenstamm + Mapping liegen serverseitig. UI (Admin-Portal, iOS) zeigt/validiert nur.

2. **Additiv statt Big Bang**  
   Vorhandene Buchungslogik bleibt zunächst intakt; neue Felder/Resolver werden sukzessive ergänzt.

3. **Versionierte Zuordnung**  
   Jede Buchung bekommt einen Snapshot der zur Buchungszeit gültigen Mapping-/Steuerdefinition.

4. **Read-First Rollout**  
   Erst Sichtbarkeit und Datenmodell, dann Schreibpfad umstellen, dann harte Validierungen aktivieren.

5. **Ressourcenschonung**  
   Minimal-invasive Änderungen pro PR, keine Vollmigration in einem Schritt, klare Fallbacks.

---

## Ziel-Datenmodell (Backend)

### 1) LedgerChartOfAccounts

- `id`
- `tenantId` (optional, falls mandantenfähig geplant)
- `code`: `SKR03` | `SKR04`
- `version`: String (z. B. `2026-05-v1`)
- `name`
- `isActive`
- `validFrom`, `validTo`
- `createdBy`, `updatedBy`, `updatedAt`

### 2) LedgerAccountMaster

- `internalAccountId` (z. B. `PLT-TAX-VST`, stabil)
- `displayName`
- `accountGroup` (`revenue`, `tax`, `expense`, `clearing`, `liability`)
- `defaultSide` (`debit`/`credit`, optional)
- `costCenterRequired` (Bool)
- `isPostingAllowed` (Bool)
- `validFrom`, `validTo`

### 3) LedgerAccountMapping

- `id`
- `internalAccountId`
- `chartCode` (`SKR03`/`SKR04`)
- `chartVersion`
- `externalAccountNumber` (z. B. `1576`)
- `accountType` (z. B. Erlös, Steuer, Verbindlichkeit)
- `taxTreatment` (z. B. `output_vat`, `input_vat`, `non_taxable`)
- `vatKey` (z. B. `U19`, `V19`, `U7`, `frei`)
- `costCenterRequired` (overridefähig)
- `validFrom`, `validTo`
- `status` (`active`, `deprecated`)

### 4) AppLedgerEntry (Erweiterung)

Bestehende Felder bleiben; neu ergänzt:

- `internalAccountId` (Mirror zu `account`, für Zukunftspfad)
- `chartCodeSnapshot`
- `chartVersionSnapshot`
- `externalAccountNumberSnapshot`
- `vatKeySnapshot`
- `taxTreatmentSnapshot`
- `mappingIdSnapshot`
- `costCenterSnapshot` (optional)
- `profitCenterSnapshot` (optional)

Hinweis: Snapshot-Felder sind immutable nach Buchungserzeugung.

---

## API/Service-Zielschnitt

### Neue Backend-Funktionen (Parse Cloud)

- `getLedgerChartCatalog()`
- `getLedgerAccountMaster()`
- `getLedgerAccountMappings({ chartCode, chartVersion })`
- `upsertLedgerAccountMapping(...)` (Admin, 4-eyes wenn kritisch)
- `validateLedgerMappingSet({ chartCode, chartVersion })`

### Resolver

`resolvePostingAccount({ internalAccountId, postingDate, context })` liefert:

- externes Konto
- Steuerbehandlung/VAT-Key
- Kostenstellenpflicht
- Snapshot-Objekt für Persistenz

---

## Admin-Portal Zielbild

### Kurzfristig (Read-only)

- App Ledger Tabelle/Karten um Anzeige ergänzen:
  - internes Konto
  - externes Konto
  - VAT-Key
  - Kontenrahmen/Version

### Mittelfristig (Konfiguration)

- Neue Admin-Seite „Kontenrahmen & Mapping“
  - Chart wählen (SKR03/SKR04)
  - Mapping je internem Konto pflegen
  - Gültigkeitszeiträume setzen
  - Validierungsreport (Lücken, Überlappungen, Duplikate)

---

## iOS/SwiftUI/MVVM Ausrichtung

- **Models**: neue Mapping-/Snapshot-DTOs als `struct`.
- **Services**: API-Zugriff über `*APIService` + Protocols.
- **ViewModels** (`@MainActor`, `final class`): nur Präsentations-/Validierungslogik, keine Kontenlogik.
- **Views**: reine Darstellung (kein Hardcoding von Kontologik).

Wichtig: iOS soll nicht selbst kontieren; Buchungslogik bleibt servergeführt.

---

## PR-Schnitt (effizient und risikoarm)

## PR1 — Datenfundament + Read-only Sichtbarkeit

### Scope

- Neue Parse-Klassen/Schema für `LedgerChartOfAccounts`, `LedgerAccountMaster`, `LedgerAccountMapping`
- Seed für initiales SKR03-Basisset (nur Kernkonten)
- `getAppLedger` response optional erweitern um Snapshot-Felder, falls vorhanden
- Admin-Portal: neue Spalten read-only (wenn Snapshot existiert)

### Non-Goals

- Keine Umstellung der Buchungserzeugung
- Keine harte Validierung blockierend

### Nutzen

- Sofortige Transparenz ohne Betriebsrisiko

---

## PR2 — Posting Resolver + Snapshot-Persistenz

### Scope

- Zentralen `resolvePostingAccount` einführen
- Trigger/Cloud-Funktionen (`invoice`, `corrections`, relevante Posting-Pfade) auf Resolver umstellen
- Beim Schreiben von `AppLedgerEntry` Snapshot-Felder verpflichtend setzen

### Guardrails

- Fallback erlaubt nur für Legacy-Datenpfade (feature flag)
- Monitoring auf „missing snapshot“

### Nutzen

- Revisionssichere Reproduzierbarkeit der Kontenzuordnung

---

## PR3 — Governance, Validierung, Export

### Scope

- Harte Validierung: keine Buchung ohne gültiges Mapping zum Buchungsdatum
- Admin-Validierungsseite (Lücken/Überlappungen)
- Exportprofil DATEV-ready (mindestens Konto, Gegenkonto-Referenz, VAT-Key, Belegreferenz, Datum, Betrag)
- Audit-Logs für Mapping-Änderungen mit 4-eyes-Freigabe für kritische Felder

### Nutzen

- Operativ belastbar für Steuerberater-Übergaben und Abschlussprozesse

---

## PR4 — Settlement‑Postings im AppLedger (Trade, Provision, Steuer)

### Scope

- Neuer Helper `utils/accountingHelper/journal.js#postLedgerPair` (atomar, Snapshot‑aware,
  idempotent über `(referenceId, referenceType, transactionType, metadata.leg)`).
- Neuer Wrapper `utils/accountingHelper/statements.js#bookSettlementEntry`
  (`AccountStatement`‑Zeile + zugehöriges GL‑Pair in einem Aufruf, Fail‑Open auf
  GL‑Seite).
- `settlement.js` schaltet alle bestehenden `bookAccountStatementEntry`‑Aufrufe auf
  `bookSettlementEntry` um, ohne Logikänderung.
- `triggers/invoice/` postet Order‑Fee‑Legs (`PLT-REV-ORD/EXC/FRG`) im
  `afterSave Invoice` für `invoiceType === 'order'`.
- `appLedger.js` deaktiviert die `entries.length === 0`‑Order‑Fee‑Synthese
  (Feature‑Flag `FIN1_LEDGER_LEGACY_FEE_SYNTHESIS`, default off).
- Kontenstamm wird um `PLT-LIAB-COM` (Provisions‑Verbindlichkeit Trader),
  `PLT-TAX-WHT`, `PLT-TAX-SOL`, `PLT-TAX-CHU` erweitert (additiv).
- iOS `AppLedgerAccount.swift` ergänzt die neuen Cases additiv; UI/Reporting fügt
  sich automatisch ein (`AccountGroup.allCases`).

### Non-Goals

- Trader‑Trade BUY/SELL bleibt ohne Aktiv‑Gegenposition (`CLT-AST-TRD`); kommt
  in PR5 inkl. Treuhand‑Bank‑Mapping (`BANK-TRT-CLT`).
- Backfill historischer Trades.
- Eigener Plattform‑Cut auf Provision (heute 100 % Trader; additiv erweiterbar
  über `PLT-REV-COM`).

### Idempotenz

- `(referenceId, referenceType, transactionType, metadata.leg)` ist der
  Doppelbuchungs‑Wächter pro GL‑Pair.
- `bookAccountStatementEntry` behält seine bestehende Doppelbuchungs‑Sicherung
  über (`tradeId`, `entryType`, `source: 'backend'`).

### Nutzen

- Lückenloser GL‑Buchungssatz pro Settlement‑Schritt → DATEV/SKR03‑Export wird
  inhaltlich belastbar.
- USt‑/Quellensteuer‑Voranmeldung direkt aus `PLT-TAX-*` ableitbar.
- Trader↔Pool‑Klammer wird über `PLT-LIAB-COM` salden‑auditierbar.

### Doku‑Checkpoint (PR4 umgesetzt)

- **Was:** Settlement‑Vorfälle erzeugen ein balanciertes GL‑Pair zusätzlich zur
  bisherigen `AccountStatement`‑Zeile; Order‑Fees werden produktiv gebucht statt
  synthetisiert.
- **Source of Truth:** `backend/parse-server/cloud/utils/accountingHelper/journal.js`,
  `utils/accountingHelper/statements.js`, `triggers/invoice/`,
  `utils/accountingHelper/settlement.js`.
- **Invarianten:**
  - Pro Settlement‑Buchung: `Σ debit == Σ credit` über alle GL‑Pairs.
  - `PLT-LIAB-COM` saldiert pro Trade auf 0 (heute), sobald Investor‑debit und
    Trader‑credit verbucht sind.
  - Kein Order‑Fee‑Eintrag mehr aus dem `entries.length === 0`‑Pfad in Default‑Konfig.
- **Risiken:** Strict‑Mapping muss die neuen Konten kennen, sonst blockt der
  Resolver. Sind in dieser ADR/PR4 mitgepflegt.
- **Mini‑Testplan:**
  - Trade‑Settlement E2E: Investor‑Provision + Trader‑Provision saldieren auf 0
    in `PLT-LIAB-COM`.
  - Quellensteuer/Soli/KiSt → entsprechende `PLT-TAX-*` Salden steigen.
  - `afterSave Invoice` (`invoiceType: 'order'`): pro `feeBreakdown`‑Komponente ein
    GL‑Pair.
  - `getAppLedger` ohne synthetische Order‑Fee‑Rows in Default‑Konfig.

---

## PR5 — Treuhand‑Bank `BANK-TRT-CLT` + Trade Cash‑Pairs (ADR-011)

### Scope

- Neues Hauptbuch‑Konto `BANK-TRT-CLT` (Treuhand‑Bankkonto Kundengelder,
  SKR03 1230, VAT 'frei'). Eintrag in `accountMappingResolver.js` und
  `admin/reports/shared.js`.
- `bookSettlementEntry` erhält Rules für `trade_buy`, `trade_sell`,
  `deposit`, `withdrawal` (siehe ADR-011 Tabelle).
- `settlement.js`: `trade_buy` / `trade_sell` werden auf `bookSettlementEntry`
  umgeschaltet.
- `triggers/wallet.js`: `deposit` / `withdrawal` werden auf
  `bookSettlementEntry` umgeschaltet.
- iOS `AppLedgerAccount.swift`: neuer Case `clientTrustBank` = `BANK-TRT-CLT`.

### Non‑Goals

- Securities‑Bestandsführung (`CLT-AST-SEC` / `CLT-LIAB-SEC`) bleibt
  off‑balance‑sheet — Phase 3.
- Reconciliation `BANK-TRT-CLT` ↔ realer Bankauszug — separater PR.
- Backfill historischer Trades — eigener Admin‑Job (geplant PR6).

### Idempotenz

- Neue Legs: `trade_buy:cash`, `trade_sell:cash`, `wallet:deposit`,
  `wallet:withdrawal`.

### Doku‑Checkpoint (PR5 umgesetzt)

- **Was:** Cash‑Flow Treuhand‑Bank ↔ Kundenverbindlichkeit ist jetzt im
  Hauptbuch geschlossen. Pro Trade summieren Order‑Fees + Provision + Steuer +
  Trade‑Cash zu einem ausgeglichenen Buchungssatz.
- **Source of Truth:** `utils/accountingHelper/statements.js` (Rules‑Tabelle),
  `utils/accountingHelper/settlement.js`, `triggers/wallet.js`.
- **Invarianten:**
  - `Σ debit == Σ credit` für jede Trade‑ID über alle gebuchten Pairs.
  - `BANK-TRT-CLT` Saldo entspricht Σ `CLT-LIAB-AVA` minus offene
    Provisionen/Steuern (Sanity‑Check, siehe Health‑Report).
- **Risiken:** Strict‑Mapping muss `BANK-TRT-CLT` kennen — in dieser ADR
  registriert.
- **Mini‑Testplan:**
  - Wallet‑Deposit → BANK‑TRT‑CLT debit + CLT‑LIAB‑AVA credit.
  - Wallet‑Withdrawal → umgekehrt.
  - Trade‑Settlement Trader BUY → Soll CLT‑LIAB‑AVA / Haben BANK‑TRT‑CLT.
  - Trade‑Settlement Trader SELL → umgekehrt.
  - Pro Trade: Σdebit == Σcredit über alle GL‑Pairs.

---

## Migration & Backfill

1. **Schema additiv deployen** (keine Downtime).
2. **Master/Mappings seeden** (SKR03 zuerst).
3. **Neue Buchungen mit Snapshot schreiben** (ab PR2).
4. **Legacy-Buchungen optional backfillen**:
   - nur wenn deterministisch ableitbar,
   - sonst marker `mappingStatus = legacy_unmapped`.
5. **Harte Validierung aktivieren**, wenn Mappings vollständig.

---

## Effizienz-/Kostenstrategie

- Keine Voll-Neubuchung historischer Daten.
- Keine Blockade des laufenden Betriebs in PR1.
- Wiederverwendung bestehender `AppLedgerEntry`-Klasse statt Parallelklasse.
- Feature Flags für risikoreiche Umschaltungen.
- Fokus auf Top-20 Konten zuerst (Pareto), statt kompletten SKR sofort.

---

## App-vs-Legacy Kompatibilität

### Benennungsregel

- **Neu schreiben:** ausschließlich `app`-Wording (z. B. `APP_ACCOUNTS`, `appServiceCharge`).
- **Alt lesen:** Legacy-Werte mit `platform` nur zur Abwärtskompatibilität.

### Kompatibilitätsmatrix (aktuell)

1. **Konto-Konstanten**
- Neu: `APP_ACCOUNTS`, `FULL_APP_ACCOUNTS`
- Alt: `PLATFORM_*` nicht mehr aktiv verwenden

2. **Transaktionstyp Service Charge**
- Neu: `appServiceCharge`
- Legacy-Read: `platformServiceCharge` bleibt im Filter/Parsing unterstützt

3. **Datenfelder auf Bestandsobjekten**
- Wenn historische Datensätze `platformServiceCharge` enthalten, weiterhin als Fallback lesen
- Neue Datensätze bevorzugen `appServiceCharge`

4. **User-Rolle in Ledger-Korrekturen**
- Neu: `userRole = "app"`
- Alt: `userRole = "platform"` nur in historischen Datensätzen toleriert

### Invarianten für Folge-PRs

- Keine neue Schreiblogik darf `platform*`-Werte erzeugen.
- Legacy-Werte dürfen nur in klar markierten Fallback-Pfaden vorkommen.
- Bei Entfernen eines Legacy-Fallbacks muss ein Migrations-/Backfill-Plan dokumentiert sein.

---

## Teststrategie (minimal aber belastbar)

1. **Unit**
- Resolver korrekt bei Datum/Gültigkeit
- VAT-Key/TaxTreatment-Mapping
- Konflikterkennung bei Zeitintervall-Überlappung

2. **Integration**
- `afterSave Invoice` schreibt vollständige Snapshot-Felder
- Korrekturpfade (`fourEyes`) nutzen Resolver

3. **Admin UI**
- Tabellen zeigen Mappingdaten robust (auch bei Legacy ohne Snapshot)

4. **Regression**
- Bestehende Ledger-Reports unverändert nutzbar

---

## Offene Entscheidungen (vor PR2 finalisieren)

- Mandantenfähigkeit jetzt oder vorbereitend?
- Externe Kontonummer als String (empfohlen) vs. Number
- Umfang des initialen SKR03 Seeds (minimal vs. breit)
- DATEV-Exportformat (CSV/EXTF) im ersten Schritt

---

## Definition of Done (Programm-Ebene)

- Jede neue Buchung enthält unveränderlichen Mapping-/Steuer-Snapshot.
- Kontenrahmenwechsel beeinflusst keine historischen Buchungen.
- Admin kann gültige Mapping-Sets prüfen/freigeben.
- Export enthält ausreichend Felder für Steuerberater/DATEV-Prozess.

---

## Doku-Checkpoint (PR2 umgesetzt)

- **Was:** Ein zentraler Ledger-Resolver wurde eingeführt und die relevanten App-Ledger-Schreibpfade speichern jetzt Mapping-Snapshots konsistent mit.
- **Warum:** Snapshot-Persistenz stellt sicher, dass jede neue Buchung mit der zum Buchungszeitpunkt verwendeten Kontenzuordnung reproduzierbar bleibt.
- **Source of Truth:** `backend/parse-server/cloud/utils/accountingHelper/accountMappingResolver.js`
- **Invarianten:**
  - Neue App-Ledger-Einträge setzen `internalAccountId` + `*Snapshot`-Felder.
  - Metadata enthält spiegelnde Snapshot-Werte für rückwärtskompatible Lesepfade.
  - Neue Service-Charge-Transaktionstypen verwenden `appServiceCharge` (Legacy-Leseunterstützung bleibt).
- **Risiken:** Bei unmapped Konten werden aktuell leere Snapshotfelder geschrieben (fail-open), damit der Betrieb nicht blockiert.
- **Mini-Testplan:**
  - Service-Charge-Invoice auslösen und prüfen, dass `AppLedgerEntry`-Rows Snapshotfelder enthalten.
  - 4-Eyes-Korrekturbuchung durchführen und Snapshotfelder auf den erzeugten Rows prüfen.
  - Investment-Escrow-Flow (reserve/deploy/release) prüfen und Snapshotfelder je Gegenbuchung validieren.
  - App-Ledger-Report öffnen und externe Konten-/VAT-Information in Tabelle + CSV verifizieren.

## Doku-Checkpoint (PR3 umgesetzt)

- **Was:** PR3 ergänzt einen Mapping-Validierungsreport, eine stricter Mapping-Option im Resolver (Feature-Flag), und einen gehärteten CSV-Export mit Mapping-Status.
- **Warum:** Governance und Exportqualität werden erhöht, ohne den laufenden Betrieb hart zu blockieren.
- **Source of Truth:** `backend/parse-server/cloud/utils/accountingHelper/accountMappingResolver.js`
- **Invarianten:**
  - `getLedgerMappingValidationReport` prüft Mapping-Coverage gegen die relevanten Ledger-Konten.
  - Strikte Mapping-Validierung wird nur aktiviert, wenn `FIN1_LEDGER_STRICT_MAPPING` gesetzt ist.
  - CSV enthält jetzt `taxTreatment`, `mappingId`, `mappingStatus`.
- **Risiken:** Beim Aktivieren von Strict-Mode können bisher ungemappte Konten Schreibpfade blockieren; daher zuerst Report prüfen.
- **Mini-Testplan:**
  - `getLedgerMappingValidationReport` aufrufen und `isValid`/`missingMappings` prüfen.
  - In Dev einmal mit und ohne `FIN1_LEDGER_STRICT_MAPPING=true` testen.
  - CSV-Export öffnen und prüfen, dass `Mapping-Status` korrekt `mapped/unmapped` ausweist.

