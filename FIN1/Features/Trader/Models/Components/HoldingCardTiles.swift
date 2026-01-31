import SwiftUI

// MARK: - Holding Card Tiles
/// Helper for generating tile data for holding cards
struct HoldingCardTiles {

    static func generateTiles(
        for holding: DepotHolding,
        showAdditionalDetails: Bool = false,
        warrantDetailsViewModel: WarrantDetailsViewModel
    ) -> [TileData] {
        var tiles: [TileData] = [
            // Always visible base information
            TileData(title: "Kategorie", value: getDerivateCategory(holding.direction ?? "Stock")),
            TileData(title: "WKN/ISIN", value: holding.wkn),
            TileData(title: "Richtung", value: holding.direction ?? "N/A"),
            TileData(title: "Basiswert", value: holding.underlyingAsset ?? "N/A")
        ]

        // Details controlled by warrant details selection
        if isDetailSelected("Bewertungstag", in: warrantDetailsViewModel) {
            tiles.append(TileData(title: "Bewertungstag", value: holding.valuationDate))
        }

        if isDetailSelected("Strike Price", in: warrantDetailsViewModel) {
            tiles.append(
                TileData(
                    title: "Strike Price",
                    value: formatStrikePrice(holding.strike, holding.underlyingAsset)
                )
            )
        }

        if isDetailSelected("Brief-Kurs", in: warrantDetailsViewModel) {
            tiles.append(
                TileData(
                    title: "Brief-Kurs (Ask)",
                    value: getMockBriefkurs(for: holding)
                )
            )
        }

        if isDetailSelected("Emittent", in: warrantDetailsViewModel) {
            tiles.append(
                TileData(
                    title: "Emittent",
                    value: getEmittentFromWKN(holding.wkn)
                )
            )
        }

        // Always show Stück and Profit as position metrics
        tiles.append(
            TileData(
                title: "Stück",
                value: holding.remainingQuantity.formattedAsLocalizedNumber()
            )
        )
        tiles.append(TileData(title: "Profit", value: calculateGewinnVerlust(holding)))

        // Additional details when expanded
        if showAdditionalDetails {
            if isDetailSelected("Geld-Kurs", in: warrantDetailsViewModel) {
                tiles.append(
                    TileData(
                        title: "Geld-Kurs (Bid)",
                        value: holding.currentPrice.formattedAsLocalizedCurrency()
                    )
                )
            }

            if isDetailSelected("Implizite Volatilität", in: warrantDetailsViewModel) {
                tiles.append(
                    TileData(
                        title: "Implizite Volatilität",
                        value: getMockImpliziteVolatilitaet(for: holding)
                    )
                )
            }

            if isDetailSelected("Omega", in: warrantDetailsViewModel) {
                tiles.append(
                    TileData(
                        title: "Omega",
                        value: getMockOmega(for: holding)
                    )
                )
            }

            if isDetailSelected("Subscription ratio", in: warrantDetailsViewModel) {
                tiles.append(
                    TileData(
                        title: "Subscriptionratio",
                        value: formatSubscriptionRatio(
                            subscriptionRatio: holding.subscriptionRatio,
                            denomination: holding.denomination,
                            isOptionsSecurity: holding.direction != nil
                        )
                    )
                )
            }

            if isDetailSelected("Ausübung", in: warrantDetailsViewModel) {
                tiles.append(
                    TileData(
                        title: "Ausübung",
                        value: getMockAusuebung(for: holding)
                    )
                )
            }
        }

        return tiles
    }

    // MARK: - Helper Methods
    private static func formatStrikePrice(_ strike: Double, _ underlyingAsset: String?) -> String {
        return DepotUtils.formatStrikePrice(strike, underlyingAsset)
    }

    private static func calculateGewinnVerlust(_ holding: DepotHolding) -> String {
        let profitLoss = holding.totalValue - (holding.purchasePrice * Double(holding.originalQuantity))
        let percentage = holding.originalQuantity > 0 ? (profitLoss / (holding.purchasePrice * Double(holding.originalQuantity))) * 100 : 0

        let currencyText = profitLoss.formatted(.currency(code: "EUR"))
        let percentageText = "\(percentage > 0 ? "+" : "")\(String(format: "%.1f", percentage))%"

        return "\(currencyText)\n\(percentageText)"
    }

    // MARK: - Mock Data Methods
    private static func getDerivateCategory(_ category: String) -> String {
        switch category.lowercased() {
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
            return category
        }
    }

    private static func getMockBriefkurs(for holding: DepotHolding) -> String {
        // Generate mock ask price (slightly higher than current price)
        let briefkursValue = holding.currentPrice * 1.05 // 5% higher than current price
        return briefkursValue.formattedAsLocalizedCurrency()
    }

    private static func getMockImpliziteVolatilitaet(for holding: DepotHolding) -> String {
        // Generate mock implied volatility based on WKN
        let hash = holding.wkn.hash
        let volatility = Double(abs(hash) % 50) + 15.0 // Range: 15-65%
        return String(format: "%.1f%%", volatility)
    }

    private static func getMockOmega(for holding: DepotHolding) -> String {
        // Generate mock Omega based on WKN
        let hash = holding.wkn.hash
        let omega = Double(abs(hash) % 10) + 0.5 // Range: 0.5-10.5
        return String(format: "%.2f", omega)
    }

    private static func formatSubscriptionRatio(
        subscriptionRatio: Double?,
        denomination: Int?,
        isOptionsSecurity: Bool
    ) -> String {
        // Prefer explicit subscription ratio if available and valid
        var effectiveRatio: Double?
        if let ratio = subscriptionRatio, ratio > 0 {
            effectiveRatio = ratio
        } else if let denomination = denomination, denomination > 0 {
            // Derive ratio from denomination when ratio was not persisted
            // Example: denomination 100 → ratio 0.01, denomination 10 → ratio 0.1
            effectiveRatio = 1.0 / Double(denomination)
        } else if isOptionsSecurity {
            // Legacy/backfill: For options/warrants without stored subscription ratio or denomination,
            // assume a typical warrant subscription ratio to avoid misleading N/A in depot.
            // This keeps depot tiles aligned with search hitlist behavior for OS warrants.
            effectiveRatio = 0.01
        }

        guard let ratio = effectiveRatio else { return "N/A" }

        if ratio == 1.0 {
            return "1,0"
        } else if ratio < 0.01 {
            return String(format: "%.4f", ratio).replacingOccurrences(of: ".", with: ",")
        } else if ratio < 0.1 {
            return String(format: "%.2f", ratio).replacingOccurrences(of: ".", with: ",")
        } else if ratio < 1.0 {
            return String(format: "%.1f", ratio).replacingOccurrences(of: ".", with: ",")
        } else {
            if ratio.truncatingRemainder(dividingBy: 1.0) == 0 {
                return String(format: "%.0f", ratio).replacingOccurrences(of: ".", with: ",")
            } else {
                return String(format: "%.1f", ratio).replacingOccurrences(of: ".", with: ",")
            }
        }
    }

    private static func getMockAusuebung(for holding: DepotHolding) -> String {
        switch holding.direction?.lowercased() {
        case "call", "put":
            return "Amerikanisch"
        case "aktie":
            return "N/A"
        default:
            return "Europäisch"
        }
    }

    private static func getEmittentFromWKN(_ wkn: String) -> String {
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
        default: return "Unknown"
        }
    }

    private static func isDetailSelected(_ itemName: String, in viewModel: WarrantDetailsViewModel) -> Bool {
        viewModel.items.first(where: { $0.name == itemName })?.isSelected ?? false
    }
}
