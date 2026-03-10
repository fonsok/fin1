---
title: "FIN1 – User-Dokumentation (Endnutzer/CSR/Admin)"
audience: ["Nutzer", "Customer Support", "Admins"]
lastUpdated: "2026-02-01"
---

## Zweck

Diese Hilfe ist **aufgabenorientiert** (“Wie mache ich X?”). Sie ist so geschrieben, dass sie in Teilen auch in eine in-app Hilfe übernommen werden kann.

## 1) Investor – typische Aufgaben

### Wie investiere ich in einen Trader?

**Voraussetzungen**
- Konto erstellt und (falls erforderlich) verifiziert.

**Schritte**
- Wähle einen Trader aus liste oder öffne “Finde Trader” und setze Filter.
- Tippe “Investieren”, gib Betrag ein.
- Bestätige das Investment (falls die App zwischen “reserviert” und “aktiv” unterscheidet).

**Ergebnis**
- Investment erscheint unter Investments; Status wird angezeigt.

### Wie sehe ich meine Performance?

- Öffne “Investments”.
- Prüfe Gesamtübersicht (investiert, aktueller Wert, Profit/Return%).
- Öffne ein Investment für Details/Trades/Dokumente (sofern verfügbar).

## 2) Trader – typische Aufgaben

### Wie platziere ich eine Order?

**Voraussetzungen**
- Trader-Rolle, Konto aktiv.

**Schritte**
- Öffne “Trading/Depot”.
- Wähle ein Wertpapier (Symbol).
- Nutze ggf. “Order Preview”, um Gebühren/Netto zu sehen.
- Wähle Ordertyp (Market/Limit/Stop/Stop-Limit), gib Parameter ein.
- Bestätige die Order.

**Ergebnis**
- Order wird erstellt; Status aktualisiert sich später (ausgeführt/storniert).

### Wie sehe ich offene Trades und Historie?

- Öffne “Trades”.
- “Offen” zeigt active/pending/partial, “Historie” zeigt abgeschlossene Trades (paginiert).

## 3) Wallet – Ein- und Auszahlungen

### Wie zahle ich Geld aus?

**Schritte**
- Wähle “Auszahlen”.
- Betrag eingeben (min. €10) und ggf. IBAN angeben.
- Bestätigen.

**Hinweis**
- Auszahlungen können Compliance-Prüfungen auslösen (z.B. große Beträge).

## 4) Dokumente & Reports

### Wo finde ich Rechnungen/Statements?

- Öffne “Profil → Notifications → Dokumente”.

## 5) Support / Help Center

### Wie erstelle ich ein Support-Ticket?

**Schritte**
- Öffne “Profil → Help Center/Support”.
- Wähle Kategorie (z.B. Account, Trading, Billing).
- Beschreibe dein Problem und sende ab.

**Ergebnis**
- Du erhältst eine Ticketnummer; Status/Updates kommen als Benachrichtigung.

### Häufige Probleme (Troubleshooting)

- **Ich kann mich nicht einloggen**
  - Prüfe E-Mail/Passwort (Passwort-Policy beachten).
  - Prüfe Netzwerk (WLAN/Mobil).
  - Bei wiederholten Fehleingaben kann es zu Lockout kommen.

- **Die App zeigt keine Live-Daten**
  - Prüfe Internetverbindung.
  - App neu starten.
  - Bei Dev/Test: LiveQuery benötigt korrektes WS-Endpoint.

## 6) Admin/CSR – Kurzreferenz (intern)

> Diese Sektion beschreibt typische Aufgaben, ohne sensible Betriebsdetails offenzulegen.

- **User Search**: Nutzer nach E-Mail/CustomerId finden.
- **Statusänderung**: Statuswechsel ist auditpflichtig (mit Reason).
- **4-Augen**: Freigaben dürfen nicht selbst genehmigt werden.
- **SLA**: Tickets priorisieren; Urgent/High haben strengere Targets.
- **Detaillierter CSR Workflow**: Siehe `06B_CSR_SUPPORT_WORKFLOW.md` (Rollenmodell, RACI, SLA, Eskalation, 4-Augen).

