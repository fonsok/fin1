# Release Checkliste – 2026-04-23 — ADR-007 Phase-2 (Service-Charge-Invoice serverseitig)

## Scope

- **Ziel:** Persistente Parse-`Invoice` für die App-Servicegebühr (`invoiceType=service_charge`) wird **serverseitig** und **idempotent** über `bookAppServiceCharge` angelegt; `afterSave Invoice` bucht **BankContraPosting** + **AppLedgerEntry** wie dokumentiert in `Documentation/ADR-007-App-Service-Charge-Cash-Balance-Debit.md`.
- **Steuerung:** Feature-Flag `serviceChargeInvoiceFromBackend` (Boolean) auf der Parse-Klasse `Configuration` (Top-Level-Feld), in `getConfig` unter **`display.serviceChargeInvoiceFromBackend`** exponiert und von iOS via `ConfigurationService.fetchRemoteDisplayConfig()` gelesen.
- **Härtung:** `beforeSave Invoice` verhindert doppelte `(invoiceType, batchId)`-Zeilen (`DUPLICATE_VALUE`); iOS überspringt bei Duplicate-Meldung den Legacy-Fallback.

## Voraussetzungen (Go / No-Go)

- **App-Build in Produktion:** Die installierte iOS-Version enthält bereits:
  - `InvestmentAPIService.bookAppServiceCharge`
  - `InvestmentCashDeductionProcessor`-Zweig für `serviceChargeInvoiceFromBackend`
  - `ParseAPIClient+CloudFunctions`: HTTP-400 → `NetworkError.badRequest(message)` (Duplicate-Erkennung)
- **Backend-Stand:** Cloud Code auf dem Zielhost enthält mindestens:
  - `bookAppServiceCharge` (`backend/parse-server/cloud/functions/investment.js`)
  - `afterSave Investment` → best-effort `bookAppServiceCharge` bei Aktivierung (`triggers/investment.js`)
  - `beforeSave Invoice` + `invoiceDuplicateGuard.js`, `afterSave Invoice` (`triggers/invoice/`)
- **Drift / Observability:** `getMirrorBasisDriftStatus` liefert erwartbar `healthy` bzw. bekannte `degraded`-Gründe sind akzeptiert/abgearbeitet (siehe Admin-Dashboard Abschnitt *Mirror-Basis Drift*).

## Flag aktivieren (Admin-Portal — UI-Text)

> **Wichtig (Backend-Verhalten):** `serviceChargeInvoiceFromBackend` steht **nicht** in `CRITICAL_PARAMETERS` (`backend/parse-server/cloud/utils/configHelper/criticalParameters.js`).  
> `requestConfigurationChange` wendet ihn daher wie **`walletFeatureEnabled`** **sofort** an (`requiresApproval: false`) — es entsteht **kein** `FourEyesRequest` in „Freigaben“.  
> Soll der Flip zwingend 4-Augen werden, muss der Parameter dort ergänzt werden (separates Produkt-Update).

1. Admin-Portal öffnen → **Konfiguration**.
2. Karte **„Anzeige“** → Zeile **„Servicegebühr-Rechnung über Server“**  
   (technischer Schlüssel `serviceChargeInvoiceFromBackend`, Anzeigename aus `admin-portal/src/pages/Configuration/parameterDefinitions.ts`).
3. Wert auf **Aktiv** setzen, **Begründung** ausfüllen, speichern.
4. **Freigaben-Tab** ist für diesen Parameter **nicht** der Workflow — Verifikation erfolgt direkt über `getConfig` / Mongo-Feld (siehe unten).

**Freigaben-Liste (Lesbarkeit):** In „Freigaben“ erscheint der **gleiche deutsche Anzeigename** über `PARAM_DISPLAY_NAMES` in `admin-portal/src/pages/Approvals/ApprovalsList.tsx`, falls später doch ein 4-Augen-Pfad ergänzt wird oder historische Anträge existieren.

## Deployment (Parse Cloud Code)

> Nur falls der Cloud-Code auf dem Zielhost **noch nicht** den oben genannten Stand hat.

1. Lokal: `./scripts/check-parse-cloud-config-helper-shadow.sh` → muss **OK** sein.
2. `rsync -avz backend/parse-server/cloud/ <host>:~/fin1-server/backend/parse-server/cloud/`
3. Auf dem Host: `rm -f ~/fin1-server/backend/parse-server/cloud/utils/configHelper.js` (Legacy-Shadow-Datei)
4. `docker compose -f docker-compose.production.yml restart parse-server`
5. Kurz warten, dann Health/Smoke (siehe unten).

## Verifikation — Backend (Soll)

**A) Flag sichtbar**

- `POST /parse/functions/getConfig` (Session oder Master-Key je nach Policy) → `result.display.serviceChargeInvoiceFromBackend === true`.

**B) End-to-End Buchungskette (Staging oder kontrollierter Prod-Canary)**

- Für eine frische Test-`Investment`-Zeile mit `serviceChargeTotal > 0` und bekannter `batchId`:
  - `bookAppServiceCharge` mit `{ investmentId }` → `{ success: true, skipped: false, invoiceId }`
  - Mongo/Parse-Abfragen:
    - `Invoice`: genau **1** Zeile mit `invoiceType=service_charge`, `batchId` gesetzt, `source=backend` (bzw. erwartetes Schema)
    - `BankContraPosting`: **2** Zeilen, `reference = PSC-<batchId>` (nicht `PSC-<invoiceId>`)
    - `AppLedgerEntry`: **3** Zeilen, `referenceId = <batchId>`, **Summe Debit = Summe Credit**
  - Zweiter Aufruf `bookAppServiceCharge` → `{ skipped: true, reason: "already booked" }`, **Counts unverändert**.

**C) Duplicate-Guard**

- Zweites direktes `POST /parse/classes/Invoice` mit identischem `(invoiceType=service_charge, batchId)` muss mit **Code 137** und bekannter Fehlermeldung scheitern.

## Verifikation — iOS (Soll)

- App neu starten oder bis zum nächsten Config-Fetch warten → Investor-Investment-Flow auslösen.
- In den Debug-Logs:
  - Pfad mit Flag `true`: Service-Charge-Invoice **serverseitig** gebucht (kein „client path“-Log für die Persistenz).
  - Bei simuliertem Duplicate: Log „**skipping client fallback**“ (kein zweiter `addInvoice`-Versuch).
- UI: Beleg/PDF weiterhin sichtbar; keine doppelte Service-Charge-Rechnung für dieselbe Batch-ID.

## Regression Guard (2026-04-28 Hotfix)

- **Symptom:** Beleg + Cash Balance vorhanden, aber **keine** App-Service-Charge im Ledger.
- **Primäre Ursache:** iOS ruft `bookAppServiceCharge` mit lokaler UUID auf, die weder Parse-`objectId` noch `batchId` ist.
- **Sekundäre Ursache (Legacy-Fallback):** `createServiceChargeInvoice` darf `batchId` **nicht** per `InvestmentBatch.get(batchId)` auflösen (Business-UUID ist kein Parse-`objectId`).

**Pflichtchecks nach Deploy:**

1. Parse-Logs enthalten bei neuem Investment **keine** 404 auf `bookAppServiceCharge` (`Investment nicht gefunden`).
2. Parse-Logs enthalten bei Legacy-Fallback **keinen** `Object not found` aus `createServiceChargeInvoice`.
3. Für jede neue Service-Charge existiert:
   - `Invoice` mit `invoiceType=service_charge` und gesetztem `batchId`,
   - `AppLedgerEntry` mit `PLT-REV-PSC`, `PLT-TAX-VAT`, `PLT-CLR-GEN`,
   - `BankContraPosting` mit `BANK-PS-NET`, `BANK-PS-VAT`.
4. Betragskonsistenz prüfen: `gross == net + vat` (z. B. 60.00 = 50.42 + 9.58).

## Rollback

1. Admin-Portal → **Konfiguration** → **„Anzeige“** → **„Servicegebühr-Rechnung über Server“** auf **Deaktiviert** (oder `requestConfigurationChange` mit `parameterName: "serviceChargeInvoiceFromBackend"`, `newValue: false`, Begründung).
2. `getConfig` verifizieren → `display.serviceChargeInvoiceFromBackend === false`.
3. Parse-Restart nur nötig, wenn parallel Cloud-Code ausgerollt wurde und zurückgesetzt werden muss (selten).

## Nacharbeit (Follow-up, nicht Teil dieses Flips)

- Nach **≥ 2** erfolgreichen wöchentlichen Drift-Checks mit `driftedDocuments=0`: Phase-2 **Cleanup** — Legacy-`invoiceService.addInvoice(invoice)` in `InvestmentCashDeductionProcessor` entfernen (separater PR), siehe ADR-007 Rollout Schritt 4.

## Referenzen

- `Documentation/ADR-007-App-Service-Charge-Cash-Balance-Debit.md`
- `Documentation/RETURN_CALCULATION_SCHEMAS.md` (Changelog)
- `.cursor/rules/ci-cd.md` — Abschnitt *FIN1-Server Deploy*
