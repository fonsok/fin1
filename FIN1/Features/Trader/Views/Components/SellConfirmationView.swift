import SwiftUI

// MARK: - Sell Confirmation View
/// Displays confirmation details after a successful sell order
struct SellConfirmationView: View {
    let onDismiss: () -> Void
    @Environment(\.themeManager) private var themeManager

    // Trade-based confirmation (preferred)
    init(trade: Trade, onDismiss: @escaping () -> Void) {
        self.trade = trade
        self.order = nil
        self.onDismiss = onDismiss
    }

    // Order-based confirmation (fallback)
    init(order: Order, onDismiss: @escaping () -> Void) {
        self.trade = nil
        self.order = order
        self.onDismiss = onDismiss
    }

    private let trade: Trade?
    private let order: Order?

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
                        Text("VERKAUFSBESTÄTIGUNG")
                            .font(ResponsiveDesign.headlineFont())
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.fontColor)

                        // Order Details
                        VStack(spacing: ResponsiveDesign.spacing(6)) {
                            Text("über")
                                .font(ResponsiveDesign.headlineFont())
                                .fontWeight(.light)
                                .foregroundColor(AppTheme.fontColor)
                                .multilineTextAlignment(.center)

                            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
                                // WKN (moved to top)
                                if let wkn = wkn, !wkn.isEmpty {
                                    HStack {
                                        Text("WKN:")
                                            .fontWeight(.light)
                                        Spacer()
                                        Text(wkn)
                                            .fontWeight(.regular)
                                    }
                                }

                                // Emittent (issuer)
                                if let wkn = wkn {
                                    HStack {
                                        Text("Emittent:")
                                            .fontWeight(.light)
                                        Spacer()
                                        Text(getEmittentFromWKN(wkn))
                                            .fontWeight(.regular)
                                    }
                                }

                                if let kategorie = kategorie {
                                    HStack {
                                        Text("Kategorie:")
                                            .fontWeight(.light)
                                        Spacer()
                                        Text(kategorie)
                                            .fontWeight(.regular)
                                    }
                                }

                                // Richtung (Call/Put)
                                if let richtung = richtung {
                                    HStack {
                                        Text("Richtung:")
                                            .fontWeight(.light)
                                        Spacer()
                                        Text(richtung)
                                            .fontWeight(.regular)
                                    }
                                }

                                if !basiswert.isEmpty {
                                    HStack {
                                        Text("Basiswert:")
                                            .fontWeight(.light)
                                        Spacer()
                                        Text(basiswert)
                                            .fontWeight(.regular)
                                    }
                                }

                                HStack {
                                    Text("Strike Price:")
                                        .fontWeight(.light)
                                    Spacer()
                                    Text(DepotUtils.formatStrikePrice(strike, basiswert.isEmpty ? nil : basiswert))
                                        .fontWeight(.regular)
                                }

                                HStack {
                                    Text("Stück:")
                                        .fontWeight(.light)
                                    Spacer()
                                    Text("\(Int(quantity)) Stück")
                                        .fontWeight(.regular)
                                }

                                HStack {
                                    Text("Geld-Kurs (Bid):")
                                        .fontWeight(.light)
                                    Spacer()
                                    Text(sellPrice.formattedAsLocalizedCurrency())
                                        .fontWeight(.regular)
                                }

                                HStack {
                                    Text("Gesamtbetrag:")
                                        .fontWeight(.light)
                                    Spacer()
                                    Text(totalAmount.formattedAsLocalizedCurrency())
                                        .fontWeight(.regular)
                                }

                                // Show P&L if available (Trade-based)
                                if let trade = trade, let pnl = trade.finalPnL {
                                    HStack {
                                        Text("Gewinn/Verlust:")
                                            .fontWeight(.light)
                                        Spacer()
                                        Text(pnl.formattedAsLocalizedCurrency())
                                            .fontWeight(.regular)
                                            .foregroundColor(pnl >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
                                    }
                                }
                            }
                            .padding(.horizontal, ResponsiveDesign.spacing(16))
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                            .background(AppTheme.accentGreen.opacity(0.5))
                            .cornerRadius(ResponsiveDesign.spacing(12))
                        }

                        // Additional Info
                        VStack(spacing: ResponsiveDesign.spacing(8)) {
                            Text("✅ Die Position wurde aus Ihrem Bestand entfernt")
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

    // MARK: - Computed Properties

    private var kategorie: String? {
        trade?.buyOrder.category ?? order?.category
    }

    private var richtung: String? {
        trade?.buyOrder.optionDirection ?? order?.optionDirection
    }

    private var basiswert: String {
        // Prefer underlying asset/wkn if available; fallback to description
        let underlying = trade?.underlyingAsset ?? order?.underlyingAsset
        if let underlyingAsset = underlying, !underlyingAsset.isEmpty { return underlyingAsset }
        return trade?.description ?? order?.description ?? ""
    }

    private var strike: Double {
        trade?.buyOrder.strike ?? order?.strike ?? 0.0
    }

    private var wkn: String? {
        trade?.wkn ?? order?.wkn
    }

    private var quantity: Double {
        // For trade-based confirmation, show the quantity of the most recent sell order
        if let trade = trade {
            // Get the most recent sell order quantity
            if let lastSellOrder = trade.sellOrders.last {
                return lastSellOrder.quantity
            } else if let legacySellOrder = trade.sellOrder {
                return legacySellOrder.quantity
            }
        }
        // For order-based confirmation, use the order quantity
        return order?.quantity ?? 0
    }

    private var sellPrice: Double {
        // For trade-based confirmation, show the price of the most recent sell order
        if let trade = trade {
            // Get the most recent sell order price
            if let lastSellOrder = trade.sellOrders.last {
                return lastSellOrder.price
            } else if let legacySellOrder = trade.sellOrder {
                return legacySellOrder.price
            }
        }
        // For order-based confirmation, use the order price
        return order?.price ?? 0
    }

    private var totalAmount: Double {
        // For trade-based confirmation, show the total amount of the most recent sell order
        if let trade = trade {
            // Get the most recent sell order total amount
            if let lastSellOrder = trade.sellOrders.last {
                return lastSellOrder.totalAmount
            } else if let legacySellOrder = trade.sellOrder {
                return legacySellOrder.totalAmount
            }
        }
        // For order-based confirmation, use the order total amount
        return order?.totalAmount ?? 0
    }
}

// MARK: - Preview
#Preview {
    SellConfirmationView(
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
            sellOrder: OrderSell(
                id: "test-sell",
                traderId: "test-trader",
                symbol: "AAPL",
                description: "Apple Inc.",
                quantity: 100,
                price: 160.0,
                totalAmount: 16000.0,
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
                limitPrice: nil,
                originalHoldingId: "test-holding"
            ),
            sellOrders: [],
            status: .completed,
            createdAt: Date(),
            completedAt: Date(),
            updatedAt: Date()
        ),
        onDismiss: {}
    )
}
