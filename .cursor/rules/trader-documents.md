---
description: Trader-Rechnungen, Sammelabrechnung (Collection Bill), Emittent vs Handelsplatz
alwaysApply: false
filePatterns: ["**/Trader/**/*.swift", "**/Invoice*.swift", "**/TradeStatement*.swift", "**/String+Emittent.swift"]
---

# Trader-Dokumente (Rechnung, Sammelabrechnung)

## GoB: Belegnummern (unveränderlich)

- **Eindeutige Belegnummern für alle Belege**: Jeder Beleg erhält eine eindeutige Belegnummer (TransactionIdService); keine Duplikate.
- **Jeder buchungstechnisch wirksame Vorgang hat einen Beleg**: Neue buchungsrelevante Vorgänge (z. B. neue Rechnungsart, neue Verrechnung) müssen einen zugehörigen Beleg mit Belegnummer erzeugen. Kein buchungstechnisch wirksamer Vorgang ohne Beleg.

## Emittent vs Handelsplatz

- **Emittent (Issuer)** = Wertpapieremittent. Es gibt eine **Emittentenliste** (WKN-Präfix → Anzeigename). Emittenten werden über das WKN-Mapping abgeleitet und in Rechnungen sowie in der Wertpapierzeile der Sammelabrechnung angezeigt.
- **Handelsplatz (Trading Venue)** = Wo gehandelt wird. **Nicht** mit Emittent verwechseln. Handelsplätze sind **nicht festgelegt** und werden **erst in Live-Produktion** belegt.

## Konstanten und Quellen

- **Emittent-Mapping (single source)**: `FIN1/Shared/Extensions/String+Emittent.swift`
  - `String.emittentName(forWKN: String) -> String`
  - Verwendung: InvoiceFactory, InvoiceDisplayViewModel, TradeCalculationService, ggf. weitere Stellen die Wertpapier-Emittenten anzeigen. **Nicht** für Handelsplatz verwenden.

- **Handelsplatz-Platzhalter**: `FIN1/Features/Trader/Models/TradeStatementDisplayData.swift`
  - `TradeStatementPlaceholders.tradingVenue` (z. B. `"—"`)
  - Verwendung: Kauf-/Verkauf-Transaktionen in der Sammelabrechnung (`tradingVenue`), TradeStatementDisplayService Fallback. Kein Hardcoding von "Vontobel" oder Emittent für Handelsplatz.

## Regeln

- **REQUIRED**: Rechnung (Buy/Sell): Wertpapier-Beschreibung enthält den **echten Emittenten** (über WKN aus Order/Holding → `String.emittentName(forWKN:)`). Kein Platzhalter "Issuer".
- **REQUIRED**: Sammelabrechnung: Wertpapierzeile (Kauf/Verkauf) = Security-Beschreibung aus der Rechnung (enthält bereits Emittent). `securityIdentifier` aus Rechnung übernehmen.
- **REQUIRED**: Handelsplatz in der Sammelabrechnung = `TradeStatementPlaceholders.tradingVenue` (Platzhalter bis Produktion). **FORBIDDEN**: Emittent oder festen Börsenamen (z. B. "Vontobel") als Handelsplatz setzen.
- **DRY**: Emittent-Logik nur in `String+Emittent.swift`; alle Anzeigen (Rechnung, Collection Bill, Trade-Breakdown) nutzen diese eine Quelle.

**Dokumentation**: `Documentation/FIN1_APP_DOCS/03_TECHNISCHE_SPEZIFIKATION.md`, Abschnitt 6 (Belege und Rechnungen). Keine separaten Implementierungs-Dateien; alle Themen in nummerierter Doku (01–10).
