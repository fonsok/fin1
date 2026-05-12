---
title: "FIN1 – App Ledger – Handbuch für Buchhalter"
audience: ["Buchhaltung", "Controlling", "Admin"]
lastUpdated: "2026-05-02"
---

## 1. Zweck und Zielgruppe

Dieses Handbuch erklärt **Funktionsweise, Konten und Nutzung des App Ledgers** in FIN1. Es richtet sich an Buchhalter und Sachbearbeiter, die:

- die **Eigenkonten der Plattform** (doppelte Buchführung) verstehen,
- Buchungen **nachvollziehen und prüfen**,
- das **Admin-Portal** (App Ledger) im Alltag nutzen und
- **Zusammenhänge** zwischen Verrechnungskonten, Erlösen und USt verstehen sollen.

Technische Implementierungsdetails (Trigger, Parse-Klassen) werden nur soweit erwähnt, wie sie für das Verständnis nötig sind.

---

## 2. Grundprinzip: Doppelte Buchführung auf Plattformebene

FIN1 führt für die **Plattform** (Betreiber) ein **internes Hauptbuch** in doppelter Buchführung:

- Jeder **Geschäftsvorfall**, der die Plattform betrifft (z. B. Gebühren von Nutzern, USt, Erstattungen), wird auf **mindestens zwei Konten** gebucht (Soll/Haben).
- Die Konten heißen **Eigenkonten** (Plattform-Konten) und sind **nicht** die Konten der Investoren oder Trader; sie bilden die **finanzielle Position der Plattform** ab.

**Wichtig:** Das App Ledger erfasst nur **plattformseitige** Vorgänge (Gebühren, Steuern, Erstattungen). Die Investoren-Konten und Einzelinvestments werden in anderen Systemteilen geführt; das Ledger ist keine Vollbilanz der App, sondern das **Buchhaltungssystem der Plattform als Dienstleisterin**.

---

## 3. Kontenrahmen (Übersicht)

Die Konten sind in **Gruppen** unterteilt. Im Admin-Portal erscheinen sie als Karten und im Filter „Konto“.

### 3.1 Erlöskonten (revenue)

| Konto-Code   | Kontobezeichnung              | Bedeutung |
|-------------|--------------------------------|-----------|
| PLT-REV-PSC | Erlös Plattformgebühr (netto)  | Netto-Erlös aus der Plattformgebühr (Service Charge), die Investoren bei Anlage zahlen. |
| PLT-REV-ORD | Erlös Ordergebühren            | Ordergebühren (z. B. von Tradern). |
| PLT-REV-EXC | Erlös Börsenplatzgebühren      | Börsenplatzgebühren. |
| PLT-REV-FRG | Fremdkostenpauschale           | Fremdkostenpauschale. |
| PLT-REV-COM | Provisionserlös                | Provisionserlöse. |

### 3.2 Steuerkonten (tax)

| Konto-Code   | Kontobezeichnung              | Bedeutung |
|-------------|--------------------------------|-----------|
| PLT-TAX-VAT | USt-Verbindlichkeit (Output)   | Gesammelte Umsatzsteuer (19 %) aus Leistungen der Plattform; Verbindlichkeit gegenüber dem Finanzamt. |
| PLT-TAX-VST | Vorsteuer (Input)             | Abzugsfähige Vorsteuer (Input VAT). |

### 3.3 Aufwandskonten (expense)

| Konto-Code   | Kontobezeichnung      | Bedeutung |
|-------------|------------------------|-----------|
| PLT-EXP-OPS | Betriebsaufwand        | Betriebsausgaben der Plattform. |
| PLT-EXP-REF | Erstattungsaufwand     | Aufwand aus Gutschriften/Erstattungen an Nutzer. |

### 3.4 Verrechnungskonten (clearing)

| Konto-Code   | Kontobezeichnung                      | Bedeutung |
|-------------|----------------------------------------|-----------|
| PLT-CLR-GEN | Verrechnungskonto                     | Allgemeines Verrechnungskonto. |
| PLT-CLR-REF | Erstattungs-Verrechnungskonto        | Verrechnung bei Erstattungen. |
| PLT-CLR-VAT | USt-Abführung Verrechnungskonto        | Verrechnung bei USt-Abführung ans Finanzamt. |
| **BANK-PS-NET** | Bank Clearing – Service Charge NET  | **Verrechnungskonto „Geldseite“** für den **Netto-Teil** der Plattformgebühr (Gegenbuchung zur Bank bei Eingang der Gebühr). |
| **BANK-PS-VAT** | Bank Clearing – Service Charge VAT | **Verrechnungskonto „Geldseite“** für den **USt-Teil** der Plattformgebühr. |

---

## 4. Zusammenhänge: Bank Clearing ↔ Erlös ↔ USt

Für die **Plattformgebühr (Service Charge)** gilt in FIN1 folgende Logik:

- Ein **Investor** zahlt bei einer Anlage eine **Brutto-Plattformgebühr** (z. B. 19 % USt. enthalten).
- Diese Gebühr wird vom Konto des Investors abgebucht; die Plattform „erhält“ den Betrag (buchhalterisch: Zufluss auf Verrechnung/Bank-Seite und gleichzeitig Erlös + USt-Verbindlichkeit).

**Doppelte Buchführung pro Rechnung (vereinfacht):**

1. **Geldseite (Verrechnung/Bank):**
   - **BANK-PS-NET** (Haben) = Netto-Anteil der erhaltenen Gebühr
   - **BANK-PS-VAT** (Haben) = USt-Anteil der erhaltenen Gebühr

2. **Erlös- und Steuerseite:**
   - **PLT-REV-PSC** (Haben) = derselbe Netto-Betrag wie bei BANK-PS-NET (Erlös Plattformgebühr netto)
   - **PLT-TAX-VAT** (Haben) = derselbe USt-Betrag wie bei BANK-PS-VAT (USt-Verbindlichkeit)

**Wichtig:**
- **BANK-PS-NET** und **PLT-REV-PSC** beziehen sich auf **dieselben** Vorgänge: Jede Buchung auf BANK-PS-NET hat eine Gegenbuchung auf PLT-REV-PSC (gleicher Betrag, gleicher Zeitpunkt, gleiche Rechnung).
- **BANK-PS-VAT** und **PLT-TAX-VAT** entsprechen einander für den USt-Teil.
- Ein Abgleich „Summe Haben BANK-PS-NET = Summe Haben PLT-REV-PSC“ (und analog für VAT) ist daher sinnvoll.

---

## 5. Entstehung der Buchungen (technischer Ablauf)

- **Auslöser:** Sobald eine **Service-Charge-Rechnung** (Plattformgebühr) in FIN1 erstellt und gespeichert wird, löst das Backend automatisch Buchungen aus.
- **Eine Rechnung erzeugt genau:**
  - 2 Buchungen auf den **Verrechnungskonten**: BANK-PS-NET (Haben), BANK-PS-VAT (Haben)
  - 2 Buchungen auf den **Erlös-/Steuerkonten**: PLT-REV-PSC (Haben), PLT-TAX-VAT (Haben)
- Die **Referenz** (z. B. Batch-ID, Rechnungs-ID) ist in den Buchungen hinterlegt; Rechnung und Ledger sind so einander zuordenbar.
- **Keine doppelte Erfassung:** Die Buchungen entstehen **nur** beim Speichern der Rechnung (nicht nochmals bei Statusänderungen von Investments). So wird Doppelbuchung vermieden.

---

## 6. Admin-Portal: App Ledger nutzen

### 6.1 Zugang

- **Menü:** Im Admin-Web-Portal in der Sidebar **„App Ledger“** wählen.
- **Berechtigung:** Nur Nutzer mit entsprechender Rechte-Rolle (z. B. Zugriff auf Finanzberichte) sehen das Menü und die Daten.

### 6.2 Oberfläche

- **Oben:** Übersichtskarten (z. B. Gesamterlös, Erstattungen, USt-Verbindlichkeit, USt abgeführt). **Wichtig (Stand 2026-05):** Die **Summen** in diesen Karten beziehen sich auf **alle** zur Filter/Suche passenden Buchungen (serverseitige **Aggregation**), **nicht** nur auf die aktuell sichtbare Tabellen-Seite — damit z. B. Salden auf Kunden-Unterkonten (1591/1592) nicht irreführend „0“ zeigen, während weiter hinten im Datensatz Buchungen existieren.
- **Darunter:** **Konten-Karten** nach Gruppen (Erlöskonten, Steuerkonten, Aufwandskonten, Verrechnungskonten). Pro Konto werden angezeigt:
  - Kontobezeichnung und Konto-Code
  - Haben / Soll / Saldo (aus den gefilterten Buchungen)
  - „Keine Buchungen“, falls für das gewählte Filterkriterium keine Buchungen vorliegen
- **Filter:**
  - **Konto:** Einzelkonto wählen (z. B. nur „Bank Clearing – Service Charge NET“ oder nur „Erlös Plattformgebühr (netto)“) oder „Alle Konten“.
  - **User-ID:** Eingabe zur Einschränkung — **nicht** nur Parse-`objectId`: bei Eingaben wie Benutzername/E-Mail wird **fuzzy** über mehrere Nutzer-Felder gematcht (serverseitig); striktes `equalTo(userId)` nur, wenn die Eingabe wie eine Parse-ObjectId aussieht.
  - **Transaktionstyp:** z. B. „Plattformgebühr“.
  - **Filter zurücksetzen** setzt alle Filter zurück.
- **Tabelle:** Liste der Buchungen mit Datum, Konto, Seite (Soll/Haben), Betrag, User, Typ, Referenz, Beschreibung; ergänzend **Gegenkonto** / **Beleg-Referenz** (Business-Referenz), soweit das Backend liefert — sinnvoll für Trade-/Investment-Zeilen und GoBD-Nachvollziehbarkeit.
- **CSV-Export:** Button „CSV Export“ lädt die aktuell gefilterten Buchungen als CSV herunter (für Excel/Weiterverarbeitung); Spalten inkl. **Business-Referenz**, soweit vorhanden.

### 6.3 Typische Nutzung

- **Alle Buchungen anzeigen:** Konto = „Alle Konten“, keine weiteren Filter → Gesamtübersicht.
- **Nur Plattformgebühr (Bank-Seite):** Konto = „Bank Clearing – Service Charge NET“ oder „Bank Clearing – Service Charge VAT“.
- **Nur Plattformgebühr (Erlös-Seite):** Konto = „Erlös Plattformgebühr (netto)“ oder USt-Konto „USt-Verbindlichkeit (Output)“.
- **Einzelnen Investor prüfen:** User-ID (z. B. `user:investor5@test.com` oder Kundennummer) eingeben.
- **Export für Monatsabschluss:** Gewünschte Filter setzen, dann „CSV Export“ → Weiterverarbeitung in Excel/Buchhaltungssoftware.

---

## 7. Prüfungen und Abgleich

Für die Buchhaltung sind folgende Abgleiche sinnvoll:

1. **Konsistenz Bank Clearing ↔ Erlös/USt**
   - Summe Haben **BANK-PS-NET** (Zeitraum) = Summe Haben **PLT-REV-PSC** (Zeitraum).
   - Summe Haben **BANK-PS-VAT** (Zeitraum) = Summe Haben **PLT-TAX-VAT** (Zeitraum) für die aus der Plattformgebühr stammenden Buchungen (Transaktionstyp „Plattformgebühr“).

2. **USt-Übersicht**
   - Die Karten „USt-Verbindlichkeit“ und „USt abgeführt“ sowie die Konten PLT-TAX-VAT / PLT-CLR-VAT nutzen, um abgeführte und offene USt im Blick zu haben.

3. **Referenz zur Rechnung**
   - In den Buchungsdetails (Beschreibung, Metadaten) sind Rechnungs-ID und ggf. Rechnungsnummer hinterlegt; bei Unstimmigkeiten kann die konkrete Rechnung in FIN1 zugeordnet werden.

4. **Alte Buchungen**
   - Ältere Buchungen, die **vor** der Einführung der doppelten Buchung auf PLT-REV-PSC/PLT-TAX-VAT entstanden sind, können weiterhin nur auf BANK-PS-NET/BANK-PS-VAT sichtbar sein; für diese Bestände existiert keine automatische Nachbuchung.

---

## 8. Transaktionstypen (Auswahl)

Im App Ledger werden u. a. folgende **Transaktionstypen** verwendet (u. a. im Filter und in der Tabelle):

| Typ (technisch)        | Anzeige            | Bedeutung |
|------------------------|--------------------|-----------|
| appServiceCharge       | Appgebühr          | Gebühr aus Service-Charge-Rechnung (Investor). |
| orderFee               | Ordergebühr        | Ordergebühren. |
| exchangeFee            | Börsenplatzgebühr  | Börsenplatzgebühren. |
| foreignCosts           | Fremdkosten        | Fremdkostenpauschale. |
| commission             | Provision           | Provisionserlös. |
| refund / creditNote    | Erstattung / Gutschrift | Erstattungen an Nutzer. |
| vatRemittance          | USt-Abführung      | Abführung USt ans Finanzamt. |
| vatInputClaim          | Vorsteuer          | Vorsteuer. |
| operatingExpense       | Betriebsausgabe     | Betriebsausgaben. |
| adjustment / reversal  | Korrektur / Storno | Korrekturbuchungen. |

---

## 9. Glossar

- **Eigenkonten:** Konten der Plattform (Betreiberin), nicht der Investoren oder Trader.
- **App Ledger:** Das interne Hauptbuch der Plattform in FIN1 (doppelte Buchführung).
- **Bank Clearing (BANK-PS-NET, BANK-PS-VAT):** Verrechnungskonten für den Zufluss der Plattformgebühr (Netto und USt); Gegenbuchung zur „Bank“-Seite.
- **PLT-REV-PSC:** Erlöskonto „Erlös Plattformgebühr (netto)“; inhaltlich dieselben Vorgänge wie BANK-PS-NET, nur auf der Erlösseite gebucht.
- **PLT-TAX-VAT:** USt-Verbindlichkeit (Output); inhaltlich derselbe USt-Betrag wie BANK-PS-VAT.
- **Service Charge / Plattformgebühr:** Von Investoren bei Anlage gezahlte Gebühr (brutto inkl. USt); wird in Netto (Erlös) und USt aufgeteilt.
- **Referenz / Batch-ID:** Verknüpfung der Buchung zu einem Vorgang (z. B. Investment-Batch, Rechnung).

---

## 10. Kurzreferenz: Wichtige Konten für die Plattformgebühr

| Was Sie prüfen wollen      | Konto im Filter wählen                    |
|----------------------------|-------------------------------------------|
| Alle Gebühren (Geldseite)  | Bank Clearing – Service Charge NET/VAT    |
| Alle Gebühren (Erlösseite) | Erlös Plattformgebühr (netto)             |
| USt aus Gebühren           | USt-Verbindlichkeit (Output)               |
| Ein Investor               | User-ID-Filter + ggf. Konto                |

Bei Fragen zur technischen Anbindung oder zu weiteren Konten (Ordergebühren, Erstattungen, USt-Abführung) wenden Sie sich an die technische Dokumentation (Developer Guide) oder die verantwortlichen Admins.

---

## 11. Investment-Status und Escrow-Buchungslogik (verbindliche Policy)

Diese Policy definiert die Buchungslogik für Investment-Status auf den internen
Kundenguthaben-Konten:

- `CLT-LIAB-AVA` (verfügbar)
- `CLT-LIAB-RSV` (reserviert)
- `CLT-LIAB-TRD` (im Handel/Pool)

### 11.1 Statusbedeutung

- `reserved`: Investment ist vorgemerkt, noch nicht im Handel.
- `active`: Kapital ist im Handel/Pool gebunden.
- `completed`: Vorgang abgeschlossen, Bindung aufgelöst.
- `cancelled`: Vorgang abgebrochen, Bindung/Rückstellung wird aufgelöst.

**Wichtig (fachlich verbindlich):**  
Im Status `reserved` darf der Nutzer das relevante (Split-)Investment löschen bzw. stornieren.
Bei dieser Löschung/Stornierung wird der reservierte Betrag auf das Nutzerkonto
zurückgebucht; dies ist sowohl in der **Cash Balance** als auch im
**Account Statement/Kontoauszug** ersichtlich.

### 11.2 Buchungsmatrix (Soll/Haben)

| Ereignis | Soll | Haben | Zweck |
|----------|------|-------|-------|
| Investment angelegt (`reserved`) | `CLT-LIAB-AVA` | `CLT-LIAB-RSV` | verfügbar → reserviert |
| User löscht/storniert in `reserved` | `CLT-LIAB-RSV` | `CLT-LIAB-AVA` | Reservierung rückgängig + Rückbuchung ins Nutzerkonto (Cash Balance/Account Statement sichtbar) |
| Statuswechsel `reserved` → `active` | `CLT-LIAB-RSV` | `CLT-LIAB-TRD` | reserviert → im Handel |
| Statuswechsel `active` → `completed` | `CLT-LIAB-TRD` | `CLT-LIAB-AVA` | Handelsbindung auflösen |
| Statuswechsel `active` → `cancelled` | `CLT-LIAB-TRD` | `CLT-LIAB-AVA` | Abbruch nach Aktivierung |
| Sonderfall `reserved` → `completed` | `CLT-LIAB-RSV` | `CLT-LIAB-AVA` | Abschluss ohne Aktivierungspfad |

### 11.3 Externes Kontenmapping (SKR03/SKR04)

Für die FiBu-Anbindung gibt es zwei valide Betriebsmodelle:

1. **Sammelkonto-Modell (stabiler Start):**  
   Alle drei internen Konten (`AVA`, `RSV`, `TRD`) mappen auf ein externes Sammelkonto (z. B. `1590`).

2. **Unterkonto-Modell (Best Practice bei höherem Volumen):**  
   Je Status ein eigenes externes Unterkonto (z. B. `1590/1591/1592`).

Die finale externe Nummernwahl erfolgt mit Steuerberater/FiBu-Vorgabe.

### 11.4 Invarianten (GoB/Prüfbarkeit)

- Kein Statuswechsel ohne korrespondierende Gegenbuchung.
- Neue Buchungen müssen Mapping-Snapshots enthalten (`mappingIdSnapshot`, `vatKeySnapshot`, etc.).
- Historische Buchungen werden nicht rückwirkend umgemappt.
- `reserved`-Storno durch User muss immer als `RSV` → `AVA` nachvollziehbar sein.

Technische Ergänzung:  
[`../INVESTMENT_ESCROW_LEDGER_SKETCH.md`](../INVESTMENT_ESCROW_LEDGER_SKETCH.md)
