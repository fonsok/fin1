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
- Ausreichendes Guthaben im Wallet.

**Schritte**
- Öffne “Trader entdecken”.
- Wähle einen Trader und prüfe Risikoklasse/Infos.
- Tippe “Investieren”, gib Betrag ein (mind. €100).
- Bestätige das Investment (falls die App zwischen “reserviert” und “aktiv” unterscheidet).

**Ergebnis**
- Investment erscheint im Portfolio; Status wird angezeigt.

### Wie sehe ich meine Performance?

- Öffne “Portfolio”.
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

### Wie zahle ich Geld ein?

**Schritte**
- Öffne “Wallet”.
- Wähle “Einzahlen”.
- Betrag eingeben (min. €10, max. €100.000).
- Bestätigen.

**Hinweis**
- Je nach Systemzustand kann eine Einzahlung zunächst als “pending” erscheinen.

### Wie zahle ich Geld aus?

**Schritte**
- Öffne “Wallet”.
- Wähle “Auszahlen”.
- Betrag eingeben (min. €10) und ggf. IBAN angeben.
- Bestätigen.

**Hinweis**
- Auszahlungen können Compliance-Prüfungen auslösen (z.B. große Beträge).

## 4) Dokumente & Reports

### Wo finde ich Rechnungen/Statements?

- Öffne “Dokumente” oder “Profil → Dokumente”.
- Filtere nach Typ (Dokument, Rechnung, Kontoauszug), falls angeboten.

## 5) Support / Help Center

### Wie erstelle ich ein Support-Ticket?

**Schritte**
- Öffne “Help Center/Support”.
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

