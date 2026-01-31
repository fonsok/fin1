import SwiftUI

// MARK: - Trader Watched Security Card
struct TraderWatchedSecurityCard: View {
    let security: SearchResult
    let position: Int
    let onRemove: () -> Void
    let onKaufenTapped: () -> Void
    @State private var showAdditionalDetails = false
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        CardContainer(
            position: position,
            positionPrefix: "",
            onPapersheetTapped: {
                openIssuerProductInfo(for: security)
            },
            chevronButton: {
                AnyView(
                    Button(action: {
                        showAdditionalDetails.toggle()
                    }, label: {
                        Image(systemName: showAdditionalDetails ? "chevron.up" : "chevron.down")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.secondaryText)
                    })
                    .buttonStyle(PlainButtonStyle())
                )
            }
        ) {
            VStack(spacing: ResponsiveDesign.spacing(8)) {
                // Main content grid using TileGrid with expandable details
                TileGrid(tiles: watchlistTiles, columns: 2)

                // Action buttons
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    // Remove button
                    Button(action: onRemove, label: {
                        Image(systemName: "trash")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.tertiaryText)
                            .padding(.horizontal, ResponsiveDesign.spacing(16))
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                            .background(AppTheme.accentRed.opacity(0.1))
                            .cornerRadius(ResponsiveDesign.spacing(6))
                    })

                    Spacer()

                    // Buy button
                    Button(action: onKaufenTapped, label: {
                        Text("KAUFEN")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.fontColor)
                            .padding(.horizontal, ResponsiveDesign.spacing(16))
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                            .background(AppTheme.buttonColor)
                            .cornerRadius(ResponsiveDesign.spacing(6))
                    })
                }
            }
        }
    }

    private var watchlistTiles: [TileData] {
        var tiles: [TileData] = [
            // Row 1: Bewertungstag, WKN
            TileData(title: "Bewertungstag", value: security.valuationDate),
            TileData(title: "WKN", value: security.wkn),

            // Row 2: Kategorie, Basiswert
            TileData(title: "Kategorie", value: getDerivateCategory(security.category ?? (security.direction ?? "Stock"))),
            TileData(title: "Basiswert", value: security.underlyingAsset ?? "N/A"),

            // Row 3: Richtung, Emittent
            TileData(title: "Richtung", value: security.direction ?? "-"),
            TileData(title: "Emittent", value: getEmittentFromWKN(security.wkn)),

            // Row 4: Strike Price, Brief-Kurs (Ask)
            TileData(title: "Strike Price", value: DepotUtils.formatStrikePrice(security.strike, security.underlyingAsset)),
            TileData(title: "Brief-Kurs (Ask)", value: formatBriefkurs(security.askPrice))
        ]

        // Add additional details if expanded
        if showAdditionalDetails {
            tiles.append(contentsOf: [
                // Row 5: Current Price, Implied Volatility
                TileData(title: "Geld-Kurs (Bid)", value: formatGeldkurs(getMockGeldkurs(for: security))),
                TileData(title: "Implizite Volatilität", value: getMockImpliziteVolatilitaet(for: security)),

                // Row 6: Omega, Exercise
                TileData(title: "Omega", value: getMockOmega(for: security)),
                TileData(title: "Subscription ratio", value: getMockSubscriptionRatio(for: security)),
                TileData(title: "Ausübung", value: getMockAusuebung(for: security))
            ])
        }

        return tiles
    }

    // MARK: - Helper Methods
    private func openIssuerProductInfo(for security: SearchResult) {
        // Open browser with issuer's product info page
        let wkn = security.wkn
        let issuerCode = String(wkn.prefix(2))
        let productInfoURL = "https://www.\(issuerCode.lowercased()).com/products/\(wkn)"

        if let url = URL(string: productInfoURL) {
            UIApplication.shared.open(url)
        }

        print("🔍 Opening product info for WKN: \(wkn) at \(productInfoURL)")
    }

    private func formatBriefkurs(_ briefkurs: String) -> String {
        // Convert German decimal format (comma) to Double, then format as German currency
        let normalizedString = briefkurs.replacingOccurrences(of: ",", with: ".")
        if let value = Double(normalizedString) {
            return value.formattedAsLocalizedCurrency()
        }
        return "\(briefkurs) €"
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

    private func getDerivateCategory(_ typ: String) -> String {
        return DerivativeCategoryMapper.mapCategory(typ)
    }

    // MARK: - Mock Data Helpers for Additional Details

    private func getMockGeldkurs(for security: SearchResult) -> String? {
        // Generate mock current price (slightly lower than ask price)
        let normalizedString = security.askPrice.replacingOccurrences(of: ",", with: ".")
        if let briefkursValue = Double(normalizedString) {
            let geldkursValue = briefkursValue * 0.95 // 5% lower than briefkurs
            return String(format: "%.2f", geldkursValue).replacingOccurrences(of: ".", with: ",")
        }
        return nil
    }

    private func getMockImpliziteVolatilitaet(for security: SearchResult) -> String {
        // Generate mock implied volatility based on WKN
        let hash = security.wkn.hash
        let volatility = Double(abs(hash) % 50) + 15.0 // Range: 15-65%
        return String(format: "%.1f%%", volatility)
    }

    private func getMockOmega(for security: SearchResult) -> String {
        // Generate mock Omega based on WKN
        let hash = security.wkn.hash
        let omega = Double(abs(hash) % 10) + 0.5 // Range: 0.5-10.5
        return String(format: "%.2f", omega)
    }

    private func getMockSubscriptionRatio(for security: SearchResult) -> String {
        // Most warrants: 0.01 (100 units = 1 share)
        // Some warrants: 0.1 (10 units = 1 share)
        // Determine based on underlying asset type
        if let underlyingAsset = security.underlyingAsset?.lowercased(),
           underlyingAsset.contains("dax") || underlyingAsset.contains("index") {
            // Index warrants typically use 0.01
            return "0.01"
        } else {
            // Stock warrants: vary between 0.01 and 0.1 based on WKN hash
            let hash = security.wkn.hash
            let useStandard = abs(hash) % 10 < 8 // 80% use 0.01, 20% use 0.1
            return useStandard ? "0.01" : "0.1"
        }
    }

    private func getMockAusuebung(for security: SearchResult) -> String {
        // Generate mock exercise type based on category
        switch security.category?.lowercased() {
        case "optionsschein":
            return "Amerikanisch"
        case "aktie":
            return "N/A"
        default:
            return "Europäisch"
        }
    }

    private func formatGeldkurs(_ geldkurs: String?) -> String {
        guard let geldkurs = geldkurs else { return "N/A" }
        // Convert German decimal format (comma) to Double, then format as German currency
        let normalizedString = geldkurs.replacingOccurrences(of: ",", with: ".")
        if let value = Double(normalizedString) {
            return value.formattedAsLocalizedCurrency()
        }
        return "\(geldkurs) €"
    }
}
