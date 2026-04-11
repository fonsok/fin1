---
title: "FIN1 – Identitäten & Kennungen"
audience: ["Entwickler", "Architektur", "Product"]
lastUpdated: "2026-04-04"
---

## Ziel

Dieses Dokument definiert **alle relevanten IDs und Kennungen** in FIN1 (User, Investor, Trader, Admin, Rechnungen, Ledger) und legt fest:

- **welche ID wofür verwendet werden darf**,
- **welche Felder nur Anzeige-/Reporting-Zwecke haben**,
- **welche Referenzen in Accounting-/Ledger-Klassen verpflichtend sind**.

Damit sollen Fehler wie die Verwechslung von `customerNumber`, `userId`, `investorId` usw. dauerhaft vermieden werden.

---

## 1. Personenidentität (User)

### 1.1 Technische Identität

- **`userId`**
  - **Art**: systemgenerierter, unveränderlicher Primärschlüssel.
  - **Beispiele**:
    - `u_3f92abf0-...` (empfohlen)
    - alternativ: stabiler String wie `user:investor2@test.com` (sofern nie neu vergeben).
  - **Verwendung (verpflichtend)**:
    - Primärschlüssel in der `_User`-Tabelle (Parse).
    - Fremdschlüssel in allen fachlichen Objekten, die einer Person gehören:
      - `Investment`, `Order`, `Trade`
      - `Invoice`
      - `AppLedgerEntry`, `BankContraPosting`
      - `Investment`, `Notification` usw.
  - **Was NICHT erlaubt ist**:
    - `username`, `email`, `customerNumber` als Ersatz für `userId` zu verwenden.

### 1.2 Login-/Anzeige-Daten

- **`username`**
  - Wird vom User (oder vom System) vergeben.
  - Darf sich ändern.
  - **Nur** für Login/UI, **nie** als technische Referenz in Ledger/Backoffice.

- **`email`**
  - Pflichtfeld für Login, Kommunikation, Recovery.
  - Darf sich ändern.
  - **Keine** Verwendung als Primärschlüssel in fachlichen Klassen.

- **`firstName`, `lastName`, `displayName`**
  - Reine Anzeigedaten.
  - Dürfen sich ändern.
  - Können als Redundanz in Belegen/Ledgern gespeichert werden (für lesbare Reports), ersetzen aber **nie** `userId`.

### 1.3 Rollen

- **`roles: [UserRole]`**
  - Mögliche Rollen (Beispiele):
    - `investor`
    - `trader`
    - `admin`
    - `csr` (Customer Support)
  - **Konzept**:
    - Ein User kann mehrere Rollen gleichzeitig haben.
    - Es gibt **keine** separate `investorId`/`traderId`, solange es sich um dieselbe Person handelt.
  - **Verwendung**:
    - Rechte-/Berechtigungsprüfung (Parse Roles, ACL).
    - Steuerung von UI-Features (welche Screens sichtbar sind).

---

## 2. Kundennummer & fachliche Kennungen

### 2.1 Kundennummer

- **`customerNumber`** / **`customerId`** (Parse-Feldname in FIN1: typischerweise `customerId`)
  - **Art**: fachliche, menschenlesbare Kennung.
  - **Rollen-Prefixe (Kunden-ID der Person, nicht Investment-Nummer):**
    - **Anleger/Investor:** `ANL-<Jahr>-<laufende Nummer>` — z.B. `ANL-2026-00001`
    - **Trader:** `TRD-<Jahr>-<laufende Nummer>` — z.B. `TRD-2026-00001`
  - **`INV-`:** reserviert für **Investitions-/Belegnummern** (z.B. Rechnungs-/Anlagebezug), **nicht** als Prefix für die Personen-Kunden-ID verwenden (Kollision mit Investment-IDs vermeiden).
  - Ältere generische Beispiele wie `BBBBB-2026-30194` sind nur noch als Schema-Platzhalter zu verstehen; implementierter Standard siehe `generateCustomerId` im Backend (`backend/parse-server/cloud/utils/helpers.js`) und `TestUserConstants` im iOS-Client.
  - Wird vom System vergeben (z.B. beim Onboarding).
  - **Eigenschaften**:
    - Stabil für die Person (ändert sich praktisch nie).
    - Kann Formatwechsel in neuen Jahrgängen bekommen, ohne historische Nummern anzupassen.
  - **Verwendung**:
    - Anzeige in Rechnungen, Kontoauszügen, Briefen.
    - Suchfeld im Admin-Portal / CSR-Portal.
    - Redundante Speicherung auf Belegen (z.B. `Invoice.customerId`) und Ledger-Einträgen.
  - **Wichtig**:
    - **Nie** anstelle von `userId` als Fremdschlüssel im Code verwenden.
    - Immer in Kombination mit `userId` sehen: `(userId, customerNumber)`.

### 2.2 Weitere fachliche Kennungen

Pro Domänenobjekt existiert eine **eigene** Kennung:

- **Investments / Orders / Trades**
  - `investmentId`, `orderId`, `tradeId`
  - Eindeutige IDs je Typ (UUID/String).

- **Rechnungen / Dokumente**
  - `invoiceId` (Parse-Objekt-ID)
  - `invoiceNumber` (fachliche, menschenlesbare Rechnungsnummer, z.B. `BBBBB-INV-20260311-00002`)

- **Ledger / Contra**
  - `ledgerEntryId` (z.B. Parse-ID eines `AppLedgerEntry`)
  - `bankContraPostingId` (Parse-ID von `BankContraPosting`)

**Regel:**
Diese IDs identifizieren **das Objekt**, nicht die Person. Die Person wird **immer** zusätzlich über `userId` referenziert.

---

## 3. Identitäten in Accounting & Ledger

### 3.1 Pflichtfelder in Ledger-nahen Klassen

Für jede buchungsrelevante Klasse (Beispiele: `AppLedgerEntry`, `BankContraPosting`, `Investment`) gelten:

- **Pflicht**:
  - `userId` (oder präziser `investorUserId` / `traderUserId`, Wert = User.userId)
  - `amount`, `currency`
  - `account` (z.B. `BANK-PS-NET`, `BANK-PS-VAT`)
  - `side` (`debit`/`credit`)
  - `reference` / `batchId` (Verknüpfung zu Trade/Batch/Invoice)

- **Empfohlene Redundanzfelder (für Reporting/UI, nicht für Logik)**:
  - `investorName` (z.B. aus `customerName` der Invoice)
  - `investorCustomerNumber` (Kundennummer)
  - ggf. weitere Metadaten (`metadata`-Objekt).

### 3.2 Rechnungen (`Invoice`)

Empfohlene Felder:

- Identität:
  - `userId` → verweist auf die technische Person (Investor oder Trader).
  - `customerId` → Kopie der `customerNumber` zum Zeitpunkt der Rechnung.
  - `customerName` → Text, der auf dem Dokument steht (kann sich später von aktuellem DisplayName unterscheiden).

- Beträge:
  - `subtotal`, `totalAmount`, `taxAmount` / `taxRate`.

- Verknüpfungen:
  - `tradeId`, `orderId`, ggf. `investmentIds`.

**Regel:**
- `Invoice.userId` ist **immer** die technische User-ID.
- `Invoice.customerId` ist **immer** die fachliche Kundennummer.
- `Invoice.customerName` ist **immer** der Dokumentenname (Text).

### 3.3 Bank Contra (`BankContraPosting`)

Empfohlene Struktur:

- Primärfelder:
  - `account` (z.B. `BANK-PS-NET`, `BANK-PS-VAT`)
  - `side` (`credit` / `debit`)
  - `amount`

- Identität:
  - `investorUserId` (oder kurz `userId`) → **immer** die technische ID.
  - `investorName` → nur für Anzeige.
  - `investorCustomerNumber` → optionale Redundanz (Kundennummer).

- Verknüpfungen:
  - `batchId` (z.B. Trade-/Batch-ID)
  - `investmentIds` (Liste beteiligter Investments)
  - `reference` (z.B. `PSC-<batchId>`)
  - `metadata` (z.B. `{ component: "net" | "vat", invoiceId, invoiceNumber, grossAmount }`)

**Wichtig:**
`investorId` darf **nicht** je nach Kontext mal die Kundennummer, mal die User-ID enthalten. Wenn historische Daten das bereits tun, ist dies ein **Legacy-Fehler**, der:

- durch Migration (Backfill) zu bereinigen ist und
- im neuen Code **nicht** mehr wiederholt werden darf.

---

## 4. Rollen: Investor vs. Trader vs. Admin

### 4.1 Rollen als Attribute, keine eigenen IDs

- Ein User kann mehrere Rollen haben:
  - Investor → darf investieren.
  - Trader → darf Strategien/Trades anbieten.
  - Admin/CSR → darf im Admin-/CSR-Portal arbeiten.

- **Kein** eigenes `investorId`/`traderId` nötig, solange:
  - es dieselbe Person ist,
  - wir in allen fachlichen Objekten `userId` + `roles` verwenden.

### 4.2 Wann wäre eine separate ID sinnvoll?

Nur wenn ein Trader eine **eigene juristische Entität** ist, die nicht 1:1 einem App-User entspricht (z.B. externer Broker mit eigener Schnittstelle). Dann:

- eigene `traderEntityId` in einer separaten Tabelle/Klasse,
- Verknüpfung User ↔ TraderEntity optional (z.B. Mitarbeiter eines Brokers).

Für FIN1 (Stand heute) wirkt es so, als wären Trader **Rollen** normaler User → separate IDs sind überflüssig.

---

## 5. Implementierungsrichtlinien (Kurzfassung)

1. **Immer `userId` für Referenzen verwenden.**
   - Egal ob Investor, Trader, Admin – Ledger, Invoices, Orders hängen immer an `userId`.

2. **Kundennummer (`customerNumber`) ist nur fachlich/anzeigbar.**
   - Darf in Dokumenten, PDFs, Admin-UI, CSV-Export erscheinen.
   - Darf in Klassen als zusätzliches Feld liegen, aber nie Logik/Joins steuern.

3. **Rollen sind Attribute des Users.**
   - Zugriffslogik: `if user.roles.contains(.investor) { ... }`.
   - Keine eigenen `investorId`/`traderId` bauen.

4. **DTO-Schicht sauber halten.**
   - In Swift: klare Mappings zwischen App-Modellen und Backend-DTOs (`BackendInvoice`, `BackendBankContraPosting`).
   - Kein „Overloading“: ein Feld hat **eine** Semantik.

5. **Accounting-/Ledger-Klassen immer mit stabilen Referenzen.**
   - `userId` + fachliche IDs (`invoiceId`, `invoiceNumber`, `tradeId`) + optionale Redundanz (`investorName`, `customerNumber`).

Damit ist festgelegt, welche IDs in FIN1 **notwendig** sind, wofür sie verwendet werden dürfen und welche IDs (z.B. separate `investorId`/`traderId`) im aktuellen Architekturzustand **nicht mehr eingeführt** werden sollten.

---

## 6. Policy für Username & Namensfelder

### 6.1 Unveränderliche Felder

- **`userId`**
  - Technischer Primärschlüssel, nie änderbar.

- **`username`**
  - Wird bei Registrierung gesetzt (oder vom System vergeben).
  - **Nach erfolgreicher Registrierung unveränderlich.**
  - Weder der User noch normale Admins können ihn ändern.

- **`firstName`, `lastName`**
  - Werden beim Onboarding erfasst.
  - **Im Normalfall unveränderlich.**
  - Namensänderung (z.B. Heirat, Tippfehler-Korrektur) erfolgt nur über:
    - Kontoschließung + Neu-Onboarding **oder**
    - eine explizite Admin-Korrektur (siehe unten).

### 6.2 Änderbare Felder

- **Adresse**
  - Straße, Hausnummer, PLZ, Ort, Land, ggf. Adresszusatz.
  - Darf vom User (oder Admin) geändert werden.
  - Änderungen können protokolliert werden, sind aber fachlich erlaubt und erwartet.

### 6.3 Admin-Korrekturen (Ausnahmen)

- In **absoluten Ausnahmefällen** (z.B. klarer Tippfehler beim Onboarding) darf ein Admin:
  - `username`, `firstName`, `lastName` korrigieren.
- Anforderungen:
  - Jede Änderung ist zu **loggen** (Wer, Wann, Altwert, Neuwert).
  - Idealerweise 4-Augen-Freigabe (zweite Adminrolle muss bestätigen).
  - Fachlich sollte diese Option sehr selten genutzt werden; Standardweg für echte Identitätswechsel bleibt Kontoschließung + Neu-Onboarding.

