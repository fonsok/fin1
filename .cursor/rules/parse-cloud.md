---
filePatterns:
  - "backend/parse-server/cloud/**/*.js"
---

# Parse Cloud Code (`backend/parse-server/cloud/`)

Gilt bei Arbeit an **Parse Cloud Functions**, **Triggers** und **`cloud/utils/**`. Ergänzt die globalen Regeln in **`ci-cd.md`** (Deploy, lokale Checks).

## Modulauflösung (Node) — kritisch

- **`require` für Konfig-Helfer:** immer **`…/configHelper/index.js`** (vollständiger Pfad bis `index.js`).
- **Nicht** `require('…/configHelper')` ohne `/index.js` — eine verwaiste Datei **`utils/configHelper.js`** auf dem Server würde das Paket **`utils/configHelper/`** überschatten (Symptome: z. B. `validateInvestmentAmountOrdering is not a function`, falsche FAQ-Platzhalter).
- **Nie** `cloud/utils/configHelper.js` ins Repo legen oder von Backups auf den Host zurückspielen.

## Vor Commit / Deploy

- `./scripts/check-parse-cloud-config-helper-shadow.sh` ausführen (scheitert, falls `cloud/utils/configHelper.js` existiert).
- `./scripts/check-parse-cloud-naming-conventions.sh` ausführen (Datei-/Endpoint-Naming, Temp-/Legacy-Namen).
- `./scripts/check-parse-cloud-aggregate-key-access.sh` ausführen (kein direkter `row._id`/`row.objectId` in Admin-Reports-Aggregates; nutze `summaryReportAggregateKey.js`).

## Deploy & Doku

- Nach Änderungen: vgl. **`ci-cd.md`** → Abschnitt **FIN1-Server Deploy** (rsync `cloud/`, Parse-Restart, ggf. `rm` Legacy-Datei wie in `scripts/deploy-to-ubuntu.sh`).
- Betrieb: **`Documentation/FIN1_APP_DOCS/06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md`** **§ 8.2.1**.
- **Buchungen / Beleg / SSOT (GoB):** `Documentation/BOOKING_AND_BELEG_SSOT.md` — `collectionBillBelegSnapshot.js`, Invarianten fail-closed, Buchungen nur aus Beleg-`metadata`.
- **Investor Positionsbetrag (Tabellen/Reports, nicht Ledger-Zeilen):** `Documentation/INVESTOR_POSITION_AMOUNT_SSOT.md` — SSOT-Modul `cloud/utils/investmentDisplayAmount.js`; Consumer u. a. Summary Report (Liste + Overview-KPI), `usersDetailInvestor.js` (User Detail). Bei Betrags-Anzeige **nie** rohes `Investment.amount` für aktivierte/abgeschlossene Zeilen ohne diese Kette.
- **Kontoauszug / Settlement-GL:** unter `utils/accountingHelper/` — `statements.js` ist die **Fassade** (gleiche öffentliche API / `require('…/statements')` unverändert); Implementierung in **`accountStatementWriter.js`** (Kontoauszugszeilen, Cash/Chain/Kompensation), **`settlementGLRules.js`** (`SETTLEMENT_GL_RULES`, Regel-Lookup), **`settlementGLPoster.js`** (Settlement-Posting, Order-Fee-Breakdown).

## Stil im Cloud-Code

- Neue Logik in passende **`functions/`** / **`triggers/`** / **`utils/`**-Module auslagern; **`main.js`** nur registrieren (`require`), nicht als Sammelplatte für große Handler.
- Berechtigungen: **`utils/permissions`** — nicht Rollen-Strings hardcoden, wo zentral definiert.
- Naming-Matrix für Parse Cloud: `Documentation/PARSE_CLOUD_NAMING_CONVENTIONS.md`.

## Modularisierung & Refactor-Policy (Risiko)

Ziel ist **weniger Fehlerfläche** und bessere Reviews — nicht nur kürzere Dateien.

### Wann splitten?

- Datei deutlich über **~250 Zeilen** *oder*
- **mehrere fachliche Verantwortlichkeiten** in einem Modul (z. B. Validierung + Posting + Persistenz vermischt) *oder*
- **ökonomisch/regulatorisch heikle** Pfade (Buchungen, Gebühren, Settlement, Reconciliation, Idempotenz).

**Reine Zeilenzahl** allein ist kein ausreichender Treiber — entscheidend ist **klare Verantwortung** und **sichere fachliche Invarianten** (Double-Entry, Rundung, Storno/Correction, Replay).

### Vor / während Umbau (kritische Domänen)

- Für **Geld-, Ledger-, Invoice-, Trade-/Investment-Settlement-Pfade**: vor oder im **selben PR** wie strukturelle Änderungen **Abdeckung sichern** — bestehende Integration/Contract-Tests erweitern oder neue **Characterization-/Referenzfälle** ergänzen („Golden“-Outputs oder feste Fixture-Erwartungen), statt nur Code zu verschieben.
- **Keine** bewusste Verhaltensänderung ohne explizite Produkt-/Finance-Freigabe und Test-Delta.

### Schnittlinien (Domäne vor Technik)

- Bevorzugt trennen nach: **Eingabe/Validierung**, **Domänenregeln**, **Posting-/Journal-Aufbau**, **Parse-Persistenz**, **Reconciliation/Audit** — nicht nur „eine Cloud Function = eine Datei“, wenn dadurch Domänen auseinanderfallen oder dupliziert werden.
- **Trigger** bleiben **dünn** (registrieren, Kontext, Delegation); schwere Logik in benachbarten Modulen (`*Trigger*.js`, `*Posting*.js`, `utils/…`), damit Retries und Tests die Logik ohne Trigger-Rahmen anfassen können.

### Idempotenz & Konsistenz

- Bestehende **Duplicate-Guards**, **batchId/referenceId**-Strategien und **unique** Annahmen nicht „refactorbedingt“ lockern.
- Neue schreibende Flows: **Idempotenz** explizit benennen (welcher Schlüssel verhindert Doppelbuch? was passiert bei Retry?).

### Multi-Leg Orders: sequentielles Speichern (orderNumber)

**REQUIRED** wenn mehrere `Order`-Zeilen in einem gekoppelten Flow angelegt werden und `beforeSave` eine **sequentielle Nummer** (`orderNumber` o. ä.) vergibt:

- **Nicht** `Parse.Object.saveAll(legs)` für diese Beine verwenden — Parse führt `beforeSave`-Hooks **parallel** aus; das führt zu Duplicate-Key-/Race-Fehlern bei sequentieller Nummerierung.
- **Stattdessen** jedes Bein **sequentiell** speichern: `for (const leg of legs) { await leg.save(null, { useMasterKey: true }); }`.
- Bei Teilerfolg: **Kompensation** (z. B. `destroyAll` der bereits angelegten Orders) und gekoppelten Status auf `ABORTED` setzen — siehe `functions/tradingPairedBuyExecution.js`.
- Referenz-Implementierung: `executePairedBuy` (Paired Buy, `legType` TRADER + MIRROR_POOL).

**Erlaubt:** `saveAll` für **unabhängige** Objekte ohne geteilte sequentielle Nummerierung (z. B. balancierte `AppLedgerEntry`-Paare mit festen Konten, keine `orderNumber`-Race).

### Abnahme (Minimum pro PR)

- `node --check` auf geänderte Dateien; **`npx jest`** im Ordner `backend/parse-server/cloud` (oder gezielte Suites für berührte Domänen).
- Wo möglich: **kein Diff** in numerischen Referenzoutputs für definierte Fixtures ohne Absprache.

### Was diese Policy absichtlich nicht ersetzt

- Architektur-Entscheide zu **Transaktionsgrenzen**, **eventual consistency** und **Kompensation** bleiben **ADR-/Runbook-Doku** — bei neuen Grenzen dort nachziehen, nicht nur Code splitten.

### Öffentliche API-Fassade (Barrel) — verbindlich bei Splits

Bei großen `utils/`- oder `accountingHelper/`-Modulen ist die **dünne Root-Datei** (`documents.js`, `investmentEscrow.js`, `investorAccountStatementMerge.js`, …) **kein** GoF-Facade zur Vereinfachung und **kein Sammelbecken für Logik**, sondern eine **stabile Import-Grenze** (Eintrittspunkt):

| Regel | FIN1-Entscheidung |
|-------|-------------------|
| **Aufgabe** | Nur **stabile Use-Cases** re-exportieren — exakt die **bisherigen `module.exports`**; **keine** neuen öffentlichen Submodule-Imports von außen (`require('…/name/submodule')` nur in Tests und innerhalb des Pakets). |
| **Overhead** | Fassade nur `require` + Re-Export (~≤60 Zeilen). **Keine** Business-Logik, keine Orchestrierung, keine Hilfsfunktionen in der Fassade. |
| **Verantwortung** | Fachlogik **ausschließlich** in Submodule (`name/queries.js`, `name/posting.js`, …) nach Domänenschnitt — nicht nach Zeilenzahl allein. Fassade kennt keine Regeln, nur Exportliste. |
| **API-Größe** | Öffentliche Oberfläche **klein halten**. Ziel: **1–5 stabile Use-Cases** pro Paket (z. B. `settlementCore` → nur `settleAndDistribute`). Größere historische APIs (z. B. `investmentEscrow` 26 Exports) dokumentieren **Stabilitäts-Tiers** in SSOT-Doku; neue Exporte nur mit Absprache — interne Helfer nicht nach außen ziehen. |
| **Stabilität** | Alle bestehenden `require('…/name')`-Pfade bleiben gültig; interne Submodule dürfen sich ändern. |
| **Tests** | **Zwei Ebenen:** (1) **Contract-/Integration** über die Fassade (bestehende Suites, Characterization). (2) **Submodule direkt** für fachliche Einheiten (Queries, Dedup, Posting-Builder, Timeline-Merge) — nicht nur die Fassade mocken. Fassade selbst nur testen, wenn sie eigene Logik hätte (unüblich). |
| **Performance** | Mechanische Splits sind unkritisch (`require`-Graph, keine Datenkopien). Nur bei zusätzlichen Async-Schichten oder Kopien messen. |
| **Abhängigkeiten** | **Einseitiger Graph** — Submodule unter `name/` importieren sich nicht zirkulär; Fassade importiert Submodule, nicht umgekehrt. Paket-intern: Submodule dürfen Geschwister importieren; **außen** nur die Fassade. |

**Nicht als Fassade behandeln:** Admin-**Registrierungs-Loader** (`fourEyes.js`, `devHelpers.js`, `reports.js`) — Side-Effect-Bootstrap (`register*`), kein reiner Re-Export. Submodule dort direkt testen (bereits üblich).

**Wann keine Fassade?** Wenn das Paket ohnehin **ein** Use-Case ist (z. B. `settlementParticipationPosting.js`) oder nur **zwei gleichrangige Geschwister** (`statements.js` → `accountStatementWriter` + `settlementGLPoster`) — dann reicht Geschwister-Modul ohne Unterordner.

**Submodule** (`name/shared.js`, `name/dataLoading.js`, …) nach **fachlicher Verantwortung** schneiden: Validierung, Domänenregeln, Posting/Journal, Parse-Persistenz, API-Row-Mapping, Dedup — jeweils **eine** klar benannte Verantwortung pro Datei.

Referenz (schmal + sauber): `settlementCore.js` (1 Export), `repair.js` (1 Export), `documents.js` (reiner Barrel).

**Breite historische APIs:** `modul/publicSurface.js` hält **Tier-Manifest + Exportliste** (keine Logik); die Fassade re-exportiert nur `publicSurface`. Package-internal = nicht auf Fassade. Contract-Tests: `*.publicSurface.test.js`. Referenz-Module: `investmentEscrow`, `investorAccountStatementMerge`, `documents`, `traderCollectionBillBelegSnapshot`, `traderAccountStatementPresentation`, `repair`, `usersDetailStatementsAndWallet`, `tradingSettlementReads`, **`permissions`** (9 Exports; Role-Listing-Helper nur in `roles.js`), **`pairedTradeMirrorSync`** (`legResolution.js`, `sellSync.js`; `applyMirrorSellSyncFromTraderLeg` package-internal — GOBD-Guard-Test liest `sellSync.js`), **`poolMirrorEconomics`** (`aggregatePool.js`, `traderSellMath.js`, `constants.js`). Doku: `INVESTMENT_ESCROW_LEDGER_SKETCH.md` §5.1, `BOOKING_AND_BELEG_SSOT.md`, `ADR-014`.

Modultabellen: `Documentation/BOOKING_AND_BELEG_SSOT.md`, `Documentation/ACCOUNT_STATEMENT_ARCHITECTURE.md`.

**Trade-Nummern:** Vergabe und Anzeige (`YYYY-NNN`, Europe/Berlin, pro Trader/Jahr) — `utils/tradeNumberAllocation.js`, SSOT via `SequenceCounter`. Spec: [`Documentation/TRADE_NUMBER_REFERENCE.md`](../Documentation/TRADE_NUMBER_REFERENCE.md).

**Per-user Overrides:** Commission-Bundle, App Service Charge, Depot-Limit — Resolver in `configHelper/resolve*.js`, 4-Augen via `usersRequest*`. Spec: [`Documentation/COMMISSION_OVERRIDE_REFERENCE.md`](../Documentation/COMMISSION_OVERRIDE_REFERENCE.md).

Kurzfassung für Leser im Repo: [`Documentation/ENGINEERING_GUIDE.md`](../Documentation/ENGINEERING_GUIDE.md) → Abschnitt *Parse Cloud: Modularisierung und Refactor-Policy*.
