---
title: "FIN1 – Produktseitige Merkmale für KI-Verständnis & FAQ-Beschreibungen"
audience: ["Produkt", "Support", "CSR", "Content", "KI/LLM-Integration"]
lastUpdated: "2026-04-04"
---

> **Dokumentations-Stand:** Begriffe „Portfolio“ (→ Investments/Investments & Performance) und „Plattform-Übersicht“ (→ App-Übersicht, slug `app_overview`) sind in Code und Doku vereinheitlicht (siehe 13_PORTFOLIO_BEGRIFF_ERSETZUNG.md).

## Zweck

Dieses Dokument listet **produktseitige Merkmale** der FIN1-App, die sich besonders gut eignen für:

1. **KI-Verständnis** – klare, eindeutige Begriffe und Abläufe, die ein LLM zuverlässig interpretieren kann.
2. **FAQ-Antworten** – Features, die sich in Frage-Antwort-Form prägnant und korrekt beschreiben lassen.

Die Auswahl berücksichtigt: fachliche Eindeutigkeit, vorhandene Dokumentation (User Guide, Requirements, FAQ-Export), klare Rollen (Investor vs. Trader) und konsistente Begriffe im Code und in der Doku.

---

## 1) Merkmale mit hohem KI-Verständnis (gut strukturiert, eindeutig)

Diese Merkmale haben klare Definitionen, stabile Begriffe und sind in Docs/Code konsistent verwendet. Sie eignen sich gut für KI-Anwendungen (Chatbot, Suche, Klassifikation).

| Merkmal | Kurzbeschreibung | Warum KI-freundlich |
|--------|-------------------|----------------------|
| **Investor – Trader entdecken** | Investoren finden aktive, verifizierte Trader über Discovery; Filter, Watchlist. | Klare User Story (US-B1), fester Begriff „Discovery“, Rolle „Investor“ vs. „Trader“. |
| **Investment erstellen (Reservierung → Aktivierung)** | Mindestbetrag €100, 24h Reservierung, dann Bestätigung; Service Charge wird berechnet. | Eindeutiger Zustandsautomat (reserved → active/cancelled), klare Beträge und Schritte. |
| **Proportionale Gewinn-/Verlustverteilung** | Gewinne/Verluste werden anteilig nach Investment-Anteil (am Trade/Investment-Pool) verteilt. | Einfache, mathematisch klare Regel; in FAQs und Requirements einheitlich formuliert. |
| **Investments & Performance (Investor)** | Übersicht: investiert, aktueller Wert, Profit, Return %; aktive vs. abgeschlossene Investments. | Klare Metriken (totalInvested, totalCurrentValue, return%), feste Begriffe. |
| **Order platzieren (Trader)** | Ordertypen: Market, Limit, Stop, Stop-Limit; Order Preview mit Gebühren/Netto. **Handelsuniversum:** strukturierte Derivate (z. B. Optionsscheine, Zertifikate), nicht Spot-Aktien/Forex als eigenständiges Produkt. | Klare Enum-Werte, fester Ablauf (Preview → Parameter → Bestätigung); Produktgrenze für KI/FAQ klar halten. |
| **Depot (Trader)** | Bestand (Holdings), laufende Orders; Depotwert aus Marktwerten — bezogen auf **Derivatepositionen** (OS, Zertifikate etc.). | Deutsche/englische Begriffe (Depot, Holdings, Laufende Orders) konsistent in App/FAQ. |
| **Konto (Ein- und Auszahlung)** | Kontostand, Einzahlung min. €10, max. €100k; Auszahlung min. €10, IBAN; serverseitig geführt. | Klare Limits und Regeln; Nutzer hat ein normales Konto. |
| **Compliance bei großen Transaktionen** | Ab €10k completed deposit/withdrawal → ComplianceEvent; ab €15k requiresReview. | Exakte Schwellenwerte, klare Ereignislogik. |
| **Dokumente & Rechnungen** | Rechnungen, Collection Bills, Kontoauszüge; Monatsauszüge nur für abgeschlossene Monate. | Klare Dokumenttypen und -regeln (z. B. keine Duplikate, nur abgeschlossene Monate). |
| **Support-Ticket** | Ticket mit Kategorie (Account, Trading, Billing); Ticketnummer, SLA, Benachrichtigung bei Lösung. | Eindeutiger Ablauf, feste Kategorien. |
| **4-Augen-Freigaben** | Freigaben nur durch anderen Admin; keine Selbstfreigabe; Audit-Log. | Klare Regel („nicht selbst genehmigen“), fester Begriff. |
| **AGB/Datenschutz/Impressum** | Servergetrieben, versioniert; Abnahme blockiert App bis akzeptiert; Delivery/Consent geloggt. | Klarer Flow (Version prüfen → anzeigen → akzeptieren), Compliance-relevant. |
| **Benachrichtigungen** | Inbox, gelesen/ungelesen, archiviert; Typen: Trades, Investments, Dokumente, Sicherheit. | Feste Kategorien, klare Zustände (isRead, isArchived). |

---

## 2) Bereiche, die sich gut in FAQs beschreiben lassen

Diese Themen sind bereits in **07_USER_GUIDE.md** und im **FAQ-Export** (scripts/faq_export.json) in Frage-Antwort-Form aufbereitet. Sie eignen sich für Help Center, Landing und KI-gestützte Antworten.

### 2.1 Bereits gut in FAQs abgedeckt (Vorlagen nutzbar)

- **Investments**
  - Wie investiere ich? (Mindestbetrag, Ablauf Reservierung → Aktivierung)
  - Wie werden Gewinne/Verluste berechnet? (proportional)
  - Kann ich mein Investment kündigen? (Rahmenbedingungen)
  - Wie wähle ich einen Trader? (Discovery, Performance, Watchlist)
  - Ist mein Investment garantiert? (Nein, Risikohinweis)
  - Maximale Verlustbegrenzung (nur eingesetztes Kapital)
- **Trading (Trader)**
  - Wie führe ich einen Trade aus? (Order platzieren, Bestätigung)
  - Welche Instrumente? **Derivate** (z. B. Optionsscheine, Knock-Outs, Bonus-/Faktor-Zertifikate u. ä.); Suche und Auswahl typischerweise über **WKN/ISIN**. **Kein** eigenständiger Handel mit Kassamarkt-Aktien, Spot-Forex oder Rohstoff-Cash — ggf. erscheinen Einzelaktien/Indizes/FX nur als **Basiswerte** der Derivate.
  - Wie werden Handelsgebühren berechnet? (Preview, Breakdown in Rechnungen)
  - Was ist die Trade-Nummer? (eindeutige Referenz)
  - Depot: Was ist das? (Holdings, laufende Orders, Depotwert)
  - Laufende Orders vs. Bestand (Holdings)
  - Verkauf einer Position (Sell Order → Abzug aus Bestand, Gewinn/Verlust)
- **Investments & Performance**
  - Wie wird der Investments-Wert berechnet?
  - Welche Zeiträume? (1 Woche, 1/3/6/12 Monate, Gesamt)
  - Aktive vs. abgeschlossene Investments
- **Rechnungen & Kontoauszüge**
  - Wo finde ich Rechnungen/Statements? (Profil → Notifications → Dokumente)
  - Wann erscheinen Monatsauszüge? (Ende des Monats, nur abgeschlossene Monate)
  - Inhalt einer Rechnung (Trade, Gebühren, Steuern, Netto, Datum)
  - Download/Teilen
- **Sicherheit & Login**
  - Face ID / Touch ID
  - Passwort vergessen (Reset-Link)
  - Datensicherheit (Verschlüsselung, TLS, Keychain, DSGVO)
  - Passwort ändern
- **Benachrichtigungen**
  - Wo verwalte ich sie? (Profil → Notifications)
  - Welche Typen? (Trades, Investments, Dokumente, Sicherheit)
  - Verlauf, gelesen/ungelesen, Filter

### 2.2 Zusätzlich für FAQs/KI empfehlenswert (prägnant formulierbar)

- **Konto (normales Konto)**
  - „Wie zahle ich Geld ein?“ (Betrag, Limits, Bestätigung)
  - „Wie zahle ich Geld aus?“ (Betrag, IBAN, min. €10)
  - „Warum wird meine Auszahlung geprüft?“ (Compliance bei großen Beträgen)
- **Onboarding/KYC**
  - „Welche Schritte hat die Registrierung?“ (personal, address, tax, experience, risk, consents, verification)
  - „Was passiert nach der Verifizierung?“ (onboardingCompleted, KYC-Status)
- **Rollen**
  - „Was ist der Unterschied zwischen Investor und Trader?“ (Investor: Kapital dem gewählten Trader zugeordnet, denselben Trade simultan ausführen lassen; Trader: führt Trades aus.)
- **App Ledger (Buchhaltung/Admin)**
  - Nur für interne/Admin-FAQs: Kontenrahmen, Bank Clearing, Erlös, USt (siehe 11_APP_LEDGER_BUCHHALTER_MANUAL.md).

---

## 3) Begriffe und Konventionen (für KI und FAQs)

Einheitliche Begriffe erhöhen das KI-Verständnis und vermeiden Mehrdeutigkeiten in FAQs.

| Begriff | Bedeutung (FIN1) |
|--------|-------------------|
| **Investor** | Nutzer, der Kapital einem gewählten Trader zuordnet und denselben Trade über die App simultan ausführen lässt (Investment). |
| **Trader** | Nutzer, der Trades ausführt. |
| **Investment-Pool** | Das dem nächsten Trade eines Traders zugeordnete Kapital (aus Investments mehrerer Investoren). |
| **Pool** | Kurzform für Investment-Pool (nur diese eine Bedeutung in Doku/FAQ). |
| **Investment** | Einzelne Beteiligung eines Investors am Kapital eines Traders (Status: reserved, active, completed, …); Mechanik: simultaner Trade. |
| **Discovery** | Bereich zum Finden und Filtern von Tradern (Investor). |
| **Depot** | Trader: Gesamtbestand (Holdings + laufende Orders) + Depotwert. |
| **Holding** | Eine abgeschlossene Position im Depot (nach Buy-Order). |
| **Order** | Kauf- oder Verkaufauftrag (Market, Limit, Stop, Stop-Limit). |
| **Trade** | Ausführung (z. B. Buy + Sell) auf **Derivate**; Status pending/active/partial/completed. |
| **Konto** | Normales Konto: Kontostand + Ein-/Auszahlungen, serverseitig geführt. |
| **Service Charge (Investor)** | Appgebühr beim Investment (z. B. appServiceChargeRate). |
| **Commission (Trader)** | Trader-Vergütung aus Gewinn (z. B. traderCommissionRate). |
| **Collection Bill** | Investor-seitiges Abrechnungsdokument (Investment-bezogen). |
| **Account Statement** | Kontoauszug (Investor/Trader); monatlich für abgeschlossene Monate. |
| **4-Augen** | Freigabe durch zweiten Admin; keine Selbstfreigabe. |
| **App-Übersicht** | FAQ-Kategorie für Landing/Übersicht (slug `app_overview`); Anzeige „App-Übersicht“. Früher „Plattform-Übersicht“ (slug `platform_overview`). |

---

## 4) Wo die Inhalte herkommen (Source of Truth)

- **Fachlich**: `02_REQUIREMENTS.md` (User Stories, Regeln), `02A_FEATURE_KATALOG_GUARDRAILS.md` (Protected Behaviors).
- **Nutzerorientiert**: `07_USER_GUIDE.md` (Aufgaben: „Wie mache ich X?“).
- **FAQs (servergetrieben)**: `getFAQCategories`, `getFAQs`; Inhalte im Backend (FAQItem/FAQCategory), Seed/Export: `scripts/faq_export.json`, `scripts/seed-faq-data.sh`.
- **Landing/Vorteile**: `LandingPlatformAdvantagesView`, `AppAdvantagesProvider` (Investor/Trader Advantages).
- **Buchhaltung/Admin**: `11_APP_LEDGER_BUCHHALTER_MANUAL.md`.

### 4.1 Best Practice: FAQ-Pflege

| Aspekt | Ist-Zustand | Best Practice | Empfehlung |
|--------|-------------|---------------|-------------|
| **Redaktion** | Eine Stelle: Admin-Portal „Hilfe & Anleitung“ (create/update/delete FAQs). | Inhalte an einem Ort pflegen, keine doppelte Pflege. | ✅ Entspricht Best Practice. Tägliche Änderungen nur im Admin-Portal. |
| **API** | App/Clients nutzen `getFAQs` / `getFAQCategories` (Daten aus Parse-DB). | Server-getriebene Inhalte, ein API-Zugang. | ✅ Entspricht Best Practice. |
| **Seed vs. DB** | Seed (`faq.js`) = Standard-Inhalt. `forceReseedFAQData` überschreibt die komplette DB mit dem Seed. | Seed nur für Erstbefüllung/Wiederherstellung; laufende Änderungen nicht durch Reseed ersetzen. | ⚠️ Reseed löscht alle im Admin angelegten/angepassten FAQs. **Regel:** Reseed nur bei Neuaufsetzen oder bewusstem Full-Reset; keine Nutzung als „Update aus Code“. |
| **Versionierung** | Seed in Git; DB-Inhalte nicht automatisch in Git. | Wichtige Inhaltsstände nachvollziehbar machen (Export, Backup). | **Umgesetzt:** Auf der Seite „Hilfe & Anleitung“ (Admin-Portal) gibt es den Button **„Export (Backup)“** – lädt die aktuellen FAQs und Kategorien als JSON (Dateiname mit Datum, z. B. `faq-backup-2026-03-14.json`). Vor einem Reseed empfohlen; Datei optional in Git oder Backup-Verzeichnis ablegen. |

**Fazit:** Die Aufteilung „Pflege im Admin-Portal, Auslieferung über getFAQs“ ist Best Practice. Damit es dabei bleibt: Reseed nur gezielt einsetzen und im Team vereinbaren, dass **„Hilfe & Anleitung“** die einzige laufende Redaktionsstelle ist; der Seed dient dem initialen Aufbau und ggf. der Wiederherstellung.

---

## 5) Kurz-Checkliste: Feature für KI/FAQ tauglich?

- [ ] Gibt es eine klare User Story oder Anforderung (z. B. in 02)?
- [ ] Ist der Ablauf/Zustand eindeutig (z. B. reserved → active)?
- [ ] Sind zentrale Begriffe in Doku und Code gleich verwendet?
- [ ] Lässt sich das Feature in 2–4 Sätzen als „Frage + Antwort“ formulieren?
- [ ] Gibt es keine doppelte Definition (z. B. nur eine „Balance“-Quelle)?

Wenn alle Punkte zutreffen, eignet sich das Merkmal gut für KI-Verständnis und FAQ-Antworten.

### Prüfergebnis (Stand: Dokumentinhalt Abschnitte 1–4, 6)

| Kriterium | Erfüllt? | Anmerkung / Lösungsvorschlag |
|-----------|----------|------------------------------|
| **1) User Story/Anforderung in 02** | ✅ Ja | Alle Merkmale aus Abschnitt 1 sind in 02 abgedeckt (US-B1–B4, US-C1–C5, US-D1–D3, US-E1–E2, US-F1, US-G1–G2, US-H1–H3, US-I1–I2). |
| **2) Ablauf/Zustand eindeutig** | ✅ Ja | Investment: reserved → active/cancelled; Trade: pending/active/partial/completed; in 02 und Glossar (Abschnitt 3) konsistent. |
| **3) Begriffe Doku/Code gleich** | ⚠️ Teilweise | **Lücke:** In Abschnitt 2.2 (Rollen-FAQ) und Glossar „Investor“ steht noch die alte Formulierung („Kapital in Pools“, „handelt mit Pool-Kapital“). **Lösung:** An 02 (US-B2) und FAQ-Seed anpassen: Rollen-FAQ und Investor-Definition auf „Kapital dem gewählten Trader zugeordnet“, „simultaner Trade“, „Trader führt Trades aus“ umstellen (siehe Korrekturen unten). |
| **4) Als Frage + Antwort formulierbar** | ✅ Ja | Abschnitt 2 listet FAQ-Themen in 2–4 Sätzen; Abschnitt 6 (AI-Einordnung) ist keine Feature-Checkliste, sondern Positionierung. |
| **5) Keine doppelte Definition** | ⚠️ Teilweise | **Konto:** ein normales Konto (kein Wallet-Feature). **Pool:** „Investment-Pool“ (Glossar) und „Pool“ / „Trader-Pool“ werden teils synonym verwendet. **Lösung:** Im Glossar explizit festhalten: „Pool“ = Kurzform für „Investment-Pool“, damit nur eine Definition gilt (siehe Korrektur unten). |

**Umgesetzte Korrekturen (Begriffe & Rollen):**

- Abschnitt 2.2 „Rollen“: FAQ-Antwort auf Formulierung „Kapital dem gewählten Trader zugeordnet; simultaner Trade“ angepasst.
- Glossar: „Investor“ an neue Mechanik angepasst; „Pool“ als Kurzform für „Investment-Pool“ ergänzt.

---

## 6) AI-Einordnung (Positionierung für KI-Suche)

Eine präzise, faktenbasierte Beschreibung hilft Suchmaschinen, Sprachassistenten und RAG-Systemen, FIN1 eindeutig einzuordnen. Nachfolgende Sätze sind für Metadaten, App-Store-Beschreibungen oder KI-Kontext geeignet.

### High-Risk-High-Gain-Einzeiler (für KI-Suche / Tagline)

| Sprache | Text |
|--------|------|
| **DE** | Die App ist eine High-Risk-High-Gain-Investment-App mit Verbindung von Investoren und Tradern: Investoren führen denselben Trade eines gewählten Traders simultan mit (Kapital dem Trader zugeordnet), anteilige Gewinn- und Verlustbeteiligung, KYC und Risikoklassifizierung für Nutzer in der EU. |
| **EN** | The app is a high-risk-high-gain investment app that connects investors and traders: investors participate in the same trade as their chosen trader (simultaneous execution, capital assigned to trader), proportional profit and loss sharing, KYC and risk classification for users in the EU. |

### Vollständige Einordnung (ein Satz)

| Sprache | Text |
|--------|------|
| **EN** | FIN1 is a mobile investment app that connects retail investors with verified traders: investors' capital is assigned to their chosen trader; when the trader executes a trade, a simultaneous trade is run with the corresponding (pool) capital; profits and losses are shared proportionally among participating investors, minus a fee for the trader. The app offers KYC, risk classification, and is aimed at users in the EU. |
| **DE** | FIN1 ist eine mobile Investment-App, die Privatanleger mit verifizierten Tradern verbindet: das Kapital der Investoren ist dem gewählten Trader zugeordnet; führt der Trader einen Trade aus, wird ein simultaner Trade mit dem entsprechenden (Pool-)Kapital ausgeführt; Gewinne und Verluste werden anteilig unter den beteiligten Investoren verteilt, abzüglich einer Vergütung für den Trader. Die App bietet KYC, Risikoklassifizierung und richtet sich an Nutzer in der EU. |

### Kurzfassung (z. B. Meta Description / App-Subtitle)

| Sprache | Text |
|--------|------|
| **EN** | Investment app linking investors and traders: same trade as chosen trader (simultaneous execution), proportional returns and risks. KYC, risk classes, EU. |
| **DE** | Investment-App für Investoren und Trader: denselben Trade wie der gewählte Trader (simultan), anteilige Gewinn- und Verlustbeteiligung. KYC, Risikoklassen, EU. |

### Warum das für die AI-Suche hilft

- **„mobile investment app“** – klare Kategorie (App-Typ).
- **„connects retail investors with verified traders“** – Zwei-Seiten-Modell (Marketplace), keine reine Trading- oder Robo-App.
- **„simultaner Trade / Kapital dem Trader zugeordnet“** – Abgrenzung zu Copy-Trading, klassischer Einzelaktien-Kasse, Spot-Forex-App, Krypto-Börse; Mechanik (Investment-Pool) eindeutig.
- **Derivate-Fokus** – FIN1 positioniert den Handel über **strukturierte Derivate** (Optionsscheine, Zertifikate …), nicht über ungebremsten Kassamarkt- oder FX-Spot-Handel; das sollte in FAQs/KI-Antworten nicht verwässert werden.
- **„proportional shares of profits and losses“** – Mechanik ist eindeutig (anteilig).
- **„KYC, risk classification, EU“** – Regulatorik und Zielmarkt für semantische Suche.

---

## 7) Landing-Page & App-Store-Optimierung für KI-Suche

Die Landing-Page der App (SwiftUI, vor Login) und die Store-Einträge (App Store / Play Store) sollten die gleiche, KI-lesbare Einordnung enthalten. So wird die App bei semantischer Suche und Voice-Assistenten besser gefunden.

### Empfohlene Maßnahmen

| Maßnahme | Wo | Inhalt (aus Abschnitt 6) |
|----------|-----|---------------------------|
| **Sichtbarer Einzeiler auf der Landing-Page** | Unter Subtitle oder als kurzer „Was ist diese App?“-Text | Kurzfassung DE/EN (denselben Trade wie gewählter Trader, simultan, anteilige Gewinn-/Verlustbeteiligung, KYC, EU). Einmal in `LandingConstants`, dann in der View anzeigen. |
| **Accessibility-Beschreibung** | `accessibilityLabel` / `accessibilityHint` auf dem Landing-Container | Vollständige AI-Einordnung (ein Satz), damit VoiceOver und ggf. On-Device-Indexierung den Inhalt erfassen. |
| **FAQ-Texte auf der Landing** | `LandingFAQProvider` („What is …?“ / „How does the system work?“) | An Abschnitt 6 und Backend-FAQ anpassen: simultaner Trade, Kapital dem Trader zugeordnet, proportionale Verteilung. Keine veraltete „Pool“-Formulierung ohne Kontext. |
| **App-Store-Subtitle** | App Store Connect / Play Console | Kurzfassung (Zeichenlimit beachten). |
| **App-Store-Beschreibung** | App Store Connect / Play Console | Erster Absatz = vollständige Einordnung (ein Satz); danach Features/Risiko. |
| **Keywords (App Store)** | Keyword-Feld | Begriffe: high-risk-high-gain, investment app, investors traders, simultaneous trade, proportional, KYC, EU. |

### Technische Umsetzung (Backend als Quelle)

- **Backend:** Cloud Function `getLandingAIContent` (`backend/parse-server/cloud/functions/landing.js`) liefert `summary`, `full`, `highRiskOneLiner` und `keywords` (DE/EN). Parameter `locale: 'de'` oder `'en'` optional; ohne Parameter werden beide Sprachen zurückgegeben. Öffentlich aufrufbar (kein Login), damit Landing, Crawler und Store-Redaktion die Texte nutzen können.
- **App:** Kann `getLandingAIContent` beim Start der Landing-Page aufrufen und die Texte für Anzeige und Accessibility (z. B. `accessibilityLabel`) verwenden.
- **LandingFAQProvider (iOS):** `landing-1` und `landing-2` sind an die gleiche Mechanik angepasst (simultaner Trade, Kapital dem Trader zugeordnet).
