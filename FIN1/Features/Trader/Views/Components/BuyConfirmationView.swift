import SwiftUI

// MARK: - Buy Confirmation View
/// Displays confirmation details after a successful buy order
struct BuyConfirmationView: View {
    let trade: Trade
    let onDismiss: () -> Void
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(8)) {
                        // Success Icon
                        Image(systemName: "checkmark")
                            .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                            .foregroundColor(AppTheme.accentGreen)

                        // Title
                        Text("KAUFBESTÄTIGUNG")
                            .font(ResponsiveDesign.titleFont())
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.fontColor)

                        // Trade Details
                        VStack(spacing: ResponsiveDesign.spacing(6)) {
                            Text("über")
                                .font(ResponsiveDesign.headlineFont())
                                .fontWeight(.light)
                                .foregroundColor(AppTheme.fontColor)
                                .multilineTextAlignment(.center)

                            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
                                // WKN (moved to top)
                                if let wkn = trade.wkn {
                                    HStack {
                                        Text("WKN:")
                                            .fontWeight(.light)
                                        Spacer()
                                        Text(wkn)
                                            .fontWeight(.regular)
                                    }
                                }

                                // Emittent (issuer)
                                if let wkn = trade.wkn {
                                    HStack {
                                        Text("Emittent:")
                                            .fontWeight(.light)
                                        Spacer()
                                        Text(getEmittentFromWKN(wkn))
                                            .fontWeight(.regular)
                                    }
                                }

                                // Kategorie (product category)
                                if let category = trade.buyOrder.category {
                                    HStack {
                                        Text("Kategorie:")
                                            .fontWeight(.light)
                                        Spacer()
                                        Text(category)
                                            .fontWeight(.regular)
                                    }
                                }

                                // Richtung (Call/Put)
                                if let optionDirection = trade.buyOrder.optionDirection {
                                    HStack {
                                        Text("Richtung:")
                                            .fontWeight(.light)
                                        Spacer()
                                        Text(optionDirection)
                                            .fontWeight(.regular)
                                    }
                                }

                                if let underlyingAsset = trade.underlyingAsset {
                                    HStack {
                                        Text("Basiswert:")
                                            .fontWeight(.light)
                                        Spacer()
                                        Text(underlyingAsset)
                                            .fontWeight(.regular)
                                    }
                                }

                                HStack {
                                    Text("Strike Price:")
                                        .fontWeight(.light)
                                    Spacer()
                                    Text(DepotUtils.formatStrikePrice(trade.buyOrder.strike ?? 0.0, trade.underlyingAsset))
                                        .fontWeight(.regular)
                                }

                                HStack {
                                    Text("Stück:")
                                        .fontWeight(.light)
                                    Spacer()
                                    Text(trade.totalQuantity.formattedAsLocalizedInteger())
                                        .fontWeight(.regular)
                                }

                                HStack {
                                    Text("Brief-Kurs (Ask):")
                                        .fontWeight(.light)
                                    Spacer()
                                    Text(trade.entryPrice.formattedAsLocalizedCurrency())
                                        .fontWeight(.regular)
                                }

                                HStack {
                                    Text("Gesamtbetrag:")
                                        .fontWeight(.light)
                                    Spacer()
                                    Text(trade.buyOrder.totalAmount.formattedAsLocalizedCurrency())
                                        .fontWeight(.regular)
                                }
                            }
                            .padding(.horizontal, ResponsiveDesign.spacing(16))
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                            .background(AppTheme.accentGreen.opacity(0.5))
                            .cornerRadius(ResponsiveDesign.spacing(12))
                        }

                        // Additional Info
                        VStack(spacing: ResponsiveDesign.spacing(8)) {
                            Text("✅ Die Position wurde in Ihren Bestand übertragen")
                            Text("📄 Die Rechnung ist in Ihrem Posteingang verfügbar")
                            Text("🔔 Sie erhalten eine Benachrichtigung über die Rechnung")
                        }
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)

                        // Action Button
                        Button(action: onDismiss, label: {
                            Text("Zum Depot")
                                .font(ResponsiveDesign.bodyFont())
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.fontColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, ResponsiveDesign.spacing(12))
                                .background(AppTheme.buttonColor)
                                .cornerRadius(ResponsiveDesign.spacing(8))
                        })
                        .padding(.horizontal, ResponsiveDesign.spacing(40))
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(20))
                    .padding(.top, ResponsiveDesign.spacing(60))
                    .padding(.bottom, ResponsiveDesign.spacing(20))
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Helper Functions

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
}

// MARK: - Preview
#Preview {
    BuyConfirmationView(
        trade: Trade(
            id: "test-trade",
            tradeNumber: 1,
            traderId: "test-trader",
            symbol: "AAPL",
            description: "Apple Inc.",
            buyOrder: OrderBuy(
                id: "test-buy",
                traderId: "test-trader",
                symbol: "AAPL",
                description: "Apple Inc.",
                quantity: 100,
                price: 150.0,
                totalAmount: 15000.0,
                status: .completed,
                createdAt: Date(),
                executedAt: Date(),
                confirmedAt: Date(),
                updatedAt: Date(),
                optionDirection: "Call",
                underlyingAsset: "Apple Inc.",
                wkn: "AAPL123",
                category: "Optionsschein",
                strike: 150.0, orderInstruction: "Market",
                limitPrice: nil
            ),
            sellOrder: nil,
            sellOrders: [],
            status: .active,
            createdAt: Date(),
            completedAt: nil,
            updatedAt: Date()
        ),
        onDismiss: {}
    )
}
