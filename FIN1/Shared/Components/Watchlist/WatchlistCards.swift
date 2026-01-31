import SwiftUI

// MARK: - Shared Remove Button Component
struct RemoveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action, label: {
            Image(systemName: "trash")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
                .opacity(0.6)
        })
    }
}

// MARK: - Watched Securities Card
struct WatchedSecuritiesCard: View {
    let instrument: MockInstrument
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(16)) {
            // Symbol and Name
            VStack(alignment: .leading, spacing: 4) {
                Text(instrument.symbol)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)

                Text(instrument.name)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }

            Spacer()

            // Price and Change
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(instrument.currentPrice, specifier: "%.2f")")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                HStack(spacing: ResponsiveDesign.spacing(4)) {
                    Image(systemName: instrument.changePercent >= 0 ? "arrow.up" : "arrow.down")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(instrument.changePercent >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)

                    Text("\(abs(instrument.changePercent), specifier: "%.1f")%")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(instrument.changePercent >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
                }
            }

            // Remove Button
            RemoveButton(action: onRemove)
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Watched Search Result Card
struct WatchedSearchResultCard: View {
    let searchResult: SearchResult
    let onRemove: () -> Void

    var body: some View {
        CardContainer(
            position: 1, // Position doesn't matter for watchlist
            onPapersheetTapped: {
                openIssuerProductInfo()
            }
        ) {
            VStack(spacing: ResponsiveDesign.spacing(8)) {
                // Main content grid using TileGrid (same as SearchResultCard)
                TileGrid(tiles: watchlistTiles, columns: 2)

                // Remove button
                HStack {
                    Spacer()
                    RemoveButton(action: onRemove)
                }
            }
        }
    }

    private var watchlistTiles: [TileData] {
        [
            // Row 1: Bewertungstag, WKN
            TileData(title: "Valuation Date", value: searchResult.valuationDate),
            TileData(title: "WKN", value: searchResult.wkn),

            // Row 2: Kategorie, Basiswert (derived from underlyingAsset)
            TileData(title: "Kategorie", value: getDerivateCategory(searchResult.category ?? (searchResult.direction ?? "Stock"))),
            TileData(title: "Basiswert", value: searchResult.underlyingAsset ?? "N/A"),

            // Row 3: Richtung (derived from typ), Emittent (derived from WKN)
            TileData(title: "Richtung", value: searchResult.direction ?? "-"),
            TileData(title: "Emittent", value: getEmittentFromWKN(searchResult.wkn)),

            // Row 4: Strike Price, Brief-Kurs (Ask)
            TileData(title: "Strike Price", value: DepotUtils.formatStrikePrice(searchResult.strike, searchResult.underlyingAsset)),
            TileData(title: "Brief-Kurs (Ask)", value: "\(searchResult.askPrice) €")
        ]
    }

    private func getDerivateCategory(_ typ: String) -> String {
        switch typ.lowercased() {
        case "call", "put":
            return "Optionsschein"
        case "aktie":
            return "Aktie"
        case "inline os":
            return "Inline OS"
        case "factor-os":
            return "Factor-OS"
        case "discount os":
            return "Discount OS"
        case "knockout":
            return "Knockout"
        default:
            return typ
        }
    }

    private func getEmittentFromWKN(_ wkn: String) -> String {
        let issuerCode = String(wkn.prefix(2))
        switch issuerCode {
        case "SG": return "Société Générale"
        case "DB": return "Deutsche Bank"
        case "VT": return "Volksbank"
        case "DZ": return "DZ Bank"
        case "BN": return "BNP Paribas"
        case "CI": return "Citigroup"
        case "GS": return "Goldman Sachs"
        case "HS": return "HSBC"
        case "JP": return "J.P. Morgan"
        case "MS": return "Morgan Stanley"
        case "UB": return "UBS"
        case "VO": return "Vontobel"
        case "AAPL", "TSLA", "MSFT", "GOOGL": return "US Stock"
        case "BMW", "DAX": return "German Stock"
        default: return "Unknown"
        }
    }
    private func openIssuerProductInfo() {
        // Open browser with issuer's product info page
        let wkn = searchResult.wkn
        let issuerCode = String(wkn.prefix(2))
        let productInfoURL = "https://www.\(issuerCode.lowercased()).com/products/\(wkn)"

        if let url = URL(string: productInfoURL) {
            UIApplication.shared.open(url)
        }

        print("🔍 Opening product info for WKN: \(wkn) at \(productInfoURL)")
    }
}

// MARK: - Watched Trader Card
struct WatchedTraderCard: View {
    let trader: MockTrader
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(16)) {
            // Trader Info
            VStack(alignment: .leading, spacing: 4) {
                Text(trader.username)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Text(trader.specialization)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }

            Spacer()

            // Performance Metrics
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(trader.totalReturn, specifier: "%.1f")%")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(trader.totalReturn >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)

                Text("Win Rate: \(trader.winRate, specifier: "%.1f")%")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }

            // Remove Button
            RemoveButton(action: onRemove)
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}
