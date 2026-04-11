---
title: "FIN1 – Ersetzung des Begriffs Portfolio"
audience: ["Produkt", "Entwicklung", "Content", "Support"]
lastUpdated: "2026-03-14"
---

## Status (2026-03-14)

Die unten beschriebenen Ersetzungen sind **umgesetzt**. Slug `portfolio` bleibt in API/Backend zur Kompatibilität; Anzeigenamen und Texte verwenden „Investments & Performance“ bzw. „Investments“.

**Ergänzung (FAQ-Kategorie):** Die ehemalige Kategorie „Plattform-Übersicht“ heißt nun **„App-Übersicht“**; Slug von `platform_overview` auf **`app_overview`** geändert. Im Code: `platformOverview` → **`appOverview`** (Swift: FAQCategory, LandingFAQProvider), Backend/Seed/Skripte/Postgres verwenden durchgängig `app_overview`.

## Ausgangslage (historisch)

Der Begriff **Portfolio** wurde uneinheitlich verwendet:

- **a)** Als FAQ-Kategorie für **Investor und Trader** („Portfolio & Performance“, slug `portfolio` / `investor_portfolio`).
- **b)** Als **Navigationspfad** in Hilfetexten (z. B. „Portfolio > Meine Investments“, „Portfolio > Investment auswählen > Auszahlung anfordern“) – obwohl der Tab in der App **„Investments“** heißt.

Ziel: Begriff **Portfolio** in der App und in nutzer sichtbaren Texten eliminieren und durch eindeutige Begriffe ersetzen.

---

## Ersetzungsmatrix

| Kontext | Aktuell | Ersetzung | Anmerkung |
|--------|---------|-----------|-----------|
| **Navigationspfad (Investor)** | „Portfolio > Meine Investments“ | **„Investments“** oder **„Meine Investments“** | Tab heißt bereits „Investments“ (TabConfiguration). |
| | „Portfolio > Investment auswählen > Auszahlung anfordern“ | **„Investments > Investment auswählen > Auszahlung anfordern“** | Einheitlich mit Tab-Namen. |
| **FAQ-Kategorie (Investor)** | „Portfolio & Performance“, slug `portfolio` | **„Investments & Performance“**, slug **`investments_performance`** | Oder: „Anlageübersicht & Performance“, slug `investor_overview`. |
| **FAQ-Kategorie (Trader)** | slug `portfolio` in Trader-FAQ-Liste | **„Depot & Performance“**, slug **`depot_performance`** | Trader haben „Depot“, nicht „Portfolio“. So sind Investor vs. Trader klar getrennt. |
| **FAQ investor_portfolio** | „Mein Portfolio“, slug `investor_portfolio` | **„Meine Investments & Performance“**, slug **`investments_performance`** | Ein Slug für Investor-Performance-FAQs. |
| **UI-Label (Investor)** | „Portfolio-Nr.: …“ (customerId) | **„Kunden-Nr.“** oder **„Kontonummer“** | Semantisch: Kundennummer / Account-ID. |
| **UI-Label** | „Portfolio owner: …“ | **„Kontoinhaber“** / **„Investor“** | Je nach Kontext. |
| **Datenmodell (Swift)** | `struct Portfolio` (InvestorPortfolioModels) | **`InvestorSummary`** oder **`InvestmentsSummary`** | Inhalt: totalValue, totalInvested, … = Zusammenfassung der Investments. |
| **Kommentare / Doku** | „portfolio operations“, „portfolio management“ | **„investment overview“ / „investments summary“** | Kein Nutzer sichtbar, aber konsistent. |

---

## Empfohlene Begriffe (kurz)

- **Investor, Anlageübersicht:** **Investments** (Tab/Bereich), **Investments & Performance** (FAQ-Kategorie), **InvestmentsSummary** (Modell).
- **Trader:** **Depot** (Bereich), **Depot & Performance** (FAQ-Kategorie), kein „Portfolio“.
- **Allgemein:** **Kunden-Nr.** statt „Portfolio-Nr.“, **Kontoinhaber/Investoren** statt „Portfolio owner“.

---

## Betroffene Stellen (Übersicht)

- **iOS:** FAQCategory (enum + Slug), FAQDataProvider, InvestorPortfolioModels (struct Portfolio), InvestmentsView, CompletedInvestmentsView (Portfolio-Nr. / Portfolio owner), NotificationsSettingsView, PrivacySettingsView, DashboardStats (totalPortfolioValue → z. B. totalInvestmentsValue), FAQKnowledgeBaseService, TicketAssignmentService, TrendModels, LandingFAQProvider.
- **Backend/Admin:** FAQCategory slug/name in MongoDB init, seed/faq.js (investor_portfolio, Titel), getInvestorPortfolio (Funktionsname kann aus Kompatibilität bleiben, nur UI/Doku anpassen).
- **Scripts:** seed_hc_faqs.py/sh/js (Navigationspfad „Portfolio > …“ → „Investments > …“, Kategorie investor_portfolio → investments_performance).
- **Admin-Portal:** FAQsPage.tsx, FAQEditor.tsx (slug `portfolio` → `investments_performance` / `depot_performance`).
- **Dokumentation:** 02_REQUIREMENTS (US-B4 „Portfolio ansehen“ → „Investment-Übersicht ansehen“ o. ä.), 03_TECHNISCHE_SPEZIFIKATION, 12_PRODUKT_MERKMALE_KI_FAQ.

---

## Hinweis Backend-API

Die Cloud Function **`getInvestorPortfolio`** kann aus API-Stabilität unverändert bleiben; nur in der **Dokumentation** und in **nutzer sichtbaren Texten** wird „Portfolio“ durch „Investments (Übersicht)“ o. ä. ersetzt. Optional: Alias oder neue Funktion `getInvestorOverview` einführen und alte als Deprecated markieren.
