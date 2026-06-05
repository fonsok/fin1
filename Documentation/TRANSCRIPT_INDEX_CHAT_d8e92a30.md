# Chat-Register (Themen → Zeilen)

**Transkript:** [d8e92a30-0f13-4d82-b60e-f5f32c79e7ae](file:///Users/ra/.cursor/projects/Users-ra-app-FIN1/agent-transcripts/d8e92a30-0f13-4d82-b60e-f5f32c79e7ae/d8e92a30-0f13-4d82-b60e-f5f32c79e7ae.jsonl)

**Format:** Eine Zeile = ein JSON-Eintrag (`role`: user | assistant). Bereich **Z.×–×** = von dieser User-Nachricht bis zur Zeile vor der nächsten User-Nachricht (Antworten + Tool-Calls dazwischen).

**Stand:** 2888 Zeilen im File (Inhalt pro Zeile oft sehr lang wegen eingebetteter Tool-Ausgaben).

---

## Schnellnavigation (Hauptblöcke)

| Thema | User-Start | ca. Bereich | Kurz |
|-------|------------|-------------|------|
| **Collection Bill Net Sell Fix** | Z.1 | Z.1–22 | Sell+Fees → Sell−Fees |
| **CB Expert Review + Production-Harden** | Z.23 | Z.23–76 | Ledger, Batch, DTOs |
| **GOB Beleg = SSOT** | Z.53 | Z.53–76 | Beleg-first, metadata |
| **Server-only / iOS Fallbacks** | Z.77 | Z.77–158 | Policy, Checkliste, Flag |
| **Deploy + Backfill (früh)** | Z.159 | Z.159–178 | .20, mirror-basis |
| **Kontoauszug: Reserved verschwindet** | Z.179 | Z.179–219 | Nach Buy nur 1 Zeile |
| **Keine Buchungen / Investments iOS** | Z.224 | Z.224–326 | stableId, Query |
| **IDs / INV-Nummer / App-Gebühr** | Z.315 | Z.315–407 | Nummerierung, Rechnungstext |
| **Phase 2 / 3 Monetär** | Z.408 | Z.408–476 | Listen, Drift-CI |
| **Escrow 1591/1592 / Residual** | Z.477 | Z.477–665 | Buchungssätze, Logs |
| **Überweisungsbetrag UI** | Z.843 | Z.843–935 | Zeile + Formel |
| **Trader Kontoauszug netto** | Z.986 | Z.986–1206 | Doppelbuchung, KAUF/VERKAUF |
| **Admin Toggle Kundensicht/GoB** | Z.1248 | Z.1248–1545 | Vertauscht, Fees |
| **WP Ledger / Einzelgebühren** | Z.1548 | Z.1548–1668 | Buy/Sell fees zeitlich |
| **feeConfigSnapshot / Schema** | Z.1691 | Z.1691–1793 | addField, CB fehlt |
| **Settlement SSOT / 3b / Logging** | Z.1942 | Z.1942–2213 | try/catch, Balance |
| **Code-Split (~300 Zeilen)** | Z.2175 | Z.2175–2313 | accountingHelper, Naming |
| **Summary Report Pool/Trader UI** | Z.2225 | Z.2225–2742 | Chevron, Belege, Pool |
| **Teil-Sell Config iOS** | Z.2658 | Z.2658–2720 | max count, hide UI |
| **Filter + Suche + Zeitraum** | Z.2709 | Z.2709–2766 | App-Ledger-Vorlage |
| **Production-Harden Suche** | Z.2767 | Z.2767–2867 | Mongo text, health |
| **Go-Live + Monitoring** | Z.2875 | Z.2875–2880 | CI, Abnahme-Doc |
| **Deploy (letzter)** | Z.2881 | Z.2881–2887 | .20, healthy |

---

## Detailliert nach Buchstaben

### A. Collection Bill – Net Sell / Formel
- **Z.1–22** — Ausgangsbug: Net Sell = Sell − Fees (1.295,47 €)
- **Z.487–495** — Kalkulationsschema 1.285,02 € (App Ledger)
- **Z.890–905** — Überweisungsbetrag = Net Sell − Commission

### B. Expert Review / Production-Harden (allgemein)
- **Z.23–26** — Review: robust/efficient?
- **Z.27–52** — Production-hardened CB implementieren
- **Z.59–76** — Beleg-first Umsetzung
- **Z.2761–2794** — Review Teil-Sell + Tabellen; „alle Ecken production-harden“

### C. GOB / Beleg / Ledger / Admin Kontoauszug
- **Z.53–58** — Keine Buchung ohne Beleg
- **Z.477–486** — Konto 1592 Soll 1.285,02
- **Z.666–711** — Admin Ledger leer
- **Z.943–946** — Residual 0,70 vs 0,71 SSOT
- **Z.1248–1422** — Toggle vertauscht; reserved fehlt in GoB
- **Z.1475–1511** — Buy/Sell-Fees in Ledger (Collection Bill)

### D. Server-only Monetär (iOS)
- **Z.77–158** — Fallbacks?, Server-only Policy, Backfill-Reihenfolge
- **Z.408–476** — Phase 2/3, `investorMonetaryServerOnly`

### E. Escrow / Residual / Doppelbuchung (1591/1592)
- **Z.496–527** — Soll 997,69 statt 1000 (Residual 2,31)
- **Z.543–565** — Korrekter Buchungssatz 1591/1592/Cash
- **Z.566–610** — Doppelbuchung ongoing+completed; Residual sofort
- **Z.611–665** — Falsche Texte „Geldeingang SELL“ / Returned
- **Z.1607–1630** — Residual 2,64 Formel

### F. Kontoauszug / Investments Anzeige (iOS)
- **Z.179–219** — Reserved-Zeilen verschwinden nach Buy
- **Z.224–290** — Keine Buchungen; Build UserFactory
- **Z.291–326** — Investments nicht in App; IDs

### G. Trader Kontoauszug (Kundensicht)
- **Z.986–1049** — Verkauf doppelt gebucht
- **Z.1050–1206** — Gebühren extra vs netto; Backend `getAccountStatement`

### H. Überweisungsbetrag / Collection Bill UI
- **Z.843–935** — Neue Zeile + Trennlinien + Freund-Vorschlag

### I. Admin Portal Benutzer-Detail
- **Z.767–842** — Kontostand spiegeln; Rollback; Punkt 1 JA
- **Z.1207–1235** — Kaufgebühren im Ledger
- **Z.1358–1393** — GoB vs Kundensicht (Investor+Admin)

### J. WP / Einzelgebühren / feeConfigSnapshot
- **Z.1521–1576** — Buy/Sell fees zum richtigen Zeitpunkt; WP-Richtung
- **Z.1691–1793** — Schema addField; Collection Bill fehlt

### K. Settlement / Logging / Phase 3b / Code-Größe
- **Z.1942–2213** — SSOT Settlement, Logging, Balance-Race, 3b, Backfill
- **Z.2175–2191** — Große Code-Dateien splitten
- **Z.2282–2313** — ≤300 Zeilen; PARSE_CLOUD_NAMING

### L. Summary Report (Trades / Pool / Belege)
- **Z.2225–2244** — Exkurs Teil-Sell; Pool-Mirror in Summary
- **Z.2254–2364** — Trader-Trade vs Pool-Mirror Labels; Backend-Zahlen
- **Z.2412–2657** — Beleg-Links, Details-Modal, Pool-Mirror Eigenbeleg

### M. Teil-Sell Konfiguration
- **Z.2214–2224** — Was tun mit kaputter Teil-Sell-Logik?
- **Z.2658–2708** — max Teil-Sells; Investor-Bereich ausblenden

### N. Summary Report — Filter, Suche, Zeitraum
- **Z.2709–2742** — Filter + Live-Suche
- **Z.2743–2760** — Vorlage App Ledger; **Zeitraum** fehlte

### O. Admin List Search / Production Ops
- **Z.2767–2813** — Mongo text index, prefix fallback, deploy
- **Z.2814–2831** — Atlas vs self-hosted Mongo
- **Z.2854–2867** — Button „Such-Index Status“ + Hover
- **Z.2868–2874** — 100 % production harden?
- **Z.2875–2887** — Go-Live + Monitoring + Abnahme; Deploy

### P. Deploy-Anfragen (Querschnitt)
- **Z.386, 890, 1129, 1244, 1387, 1514, 1543, 1880, 2245, 2365, 2881** — jeweils „deploy“ / „deploy etc“

### Q. Build-Fixes / Continue / ja
- **Z.280, 394** — Swift Build-Fehler
- **Z.83–117, 220, 454+** — Fortsetzungen und Bestätigungen (über gesamten Chat verteilt)

### R. Sonstiges
- **Z.966–985** — Simulator hängt / Landing View
- **Z.799–811** — Admin Login nach Hard Refresh
- **Z.964–965** — Cursor-Regel BOOKING_AND_BELEG nötig?

---

## Wichtige Artefakte (Repo, nicht Zeilen)

| Thema | Doku / Code |
|-------|-------------|
| Beleg SSOT | `Documentation/BOOKING_AND_BELEG_SSOT.md` |
| Admin-Suche | `Documentation/ADMIN_LIST_SEARCH.md`, `STABILIZATION_V1_CHECKLIST.md` §6 |
| Abnahme Suche | `Documentation/RELEASE_ABNAHME_SUMMARY_REPORT_SEARCH.md` |
| Summary Report UI | `admin-portal/src/pages/Reports/SummaryReportPage.tsx` |

---

## So suchst du im Transkript

1. In Cursor: Transkript öffnen (UUID oben).
2. **Gehe zu Zeile** (Cmd+G): z. B. `2709` für Filter/Suche.
3. Oder im File suchen: `user_query`, Stichwort, Dateiname.

*Erzeugt als Navigationshilfe; bei neuen Nachrichten Zeilennummern verschieben sich.*
