import SwiftUI

// MARK: - Holding Card
/// Displays individual holding information with sell functionality
struct HoldingCard: View {
    let holding: DepotHolding
    let ongoingOrders: [Order]
    @ObservedObject var warrantDetailsViewModel: WarrantDetailsViewModel
    @Environment(\.appServices) private var services
    @State private var showSellOrder = false
    @State private var showAdditionalDetails = false
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        CardContainer(
            position: holding.position,
            showWatchlistIcon: false,
            isInWatchlist: services.traderService.isInWatchlist(holding.wkn),
            onPapersheetTapped: {
                openIssuerProductInfo(for: holding)
            },
            onWatchlistTapped: {
                toggleWatchlist()
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
                // Show partial sales progress if applicable
                if holding.isPartiallySold {
                    partialSalesProgressView
                }

                // Main content grid using TileGrid
                TileGrid(
                    tiles: HoldingCardTiles.generateTiles(
                        for: holding,
                        showAdditionalDetails: showAdditionalDetails,
                        warrantDetailsViewModel: warrantDetailsViewModel
                    ),
                    columns: 2
                )

                // Sell button or info tile based on remaining quantity and existing sell orders
                sellActionView
            }
        }
        .sheet(isPresented: $showSellOrder) {
            SellOrderViewWrapper(
                holding: holding,
                traderService: services.traderService,
                userService: services.userService
            )
        }
    }

    // MARK: - Partial Sales Progress View
    private var partialSalesProgressView: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(AppTheme.accentLightBlue)
                Text("Partial Sale Progress")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentLightBlue)
                Spacer()
            }

            HStack {
                Text("Sold: \(holding.soldQuantity)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.secondaryText)
                Spacer()
                Text("Remaining: \(holding.remainingQuantity)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.secondaryText)
            }

            ProgressView(value: Double(holding.soldQuantity), total: Double(holding.originalQuantity))
                .progressViewStyle(LinearProgressViewStyle(tint: AppTheme.accentLightBlue))
        }
        .padding(.horizontal, ResponsiveDesign.spacing(12))
        .padding(.vertical, ResponsiveDesign.spacing(8))
        .background(AppTheme.accentLightBlue.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(6))
    }

    // MARK: - Sell Action View
    private var sellActionView: some View {
        let sellOrderStatus = HoldingSellOrderStatus(holding: holding, ongoingOrders: ongoingOrders)

        if holding.remainingQuantity <= 0 {
            // Show info tile when fully sold
            return AnyView(fullySoldInfoView)
        } else if sellOrderStatus.hasActiveSellOrder {
            // Show active sell order status
            return AnyView(activeSellOrderView(sellOrderStatus))
        } else {
            // Show sell button
            return AnyView(sellButtonView)
        }
    }

    private var fullySoldInfoView: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.accentGreen)
                Text("Fully Sold")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.accentGreen)
                Spacer()
            }

            Text("This holding has been completely sold.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, ResponsiveDesign.spacing(12))
        .padding(.vertical, ResponsiveDesign.spacing(8))
        .background(AppTheme.accentGreen.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(6))
    }

    private func activeSellOrderView(_ sellOrderStatus: HoldingSellOrderStatus) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(AppTheme.accentOrange)
                Text("Sell Order Active")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.accentOrange)
                Spacer()
            }

            Text("Status: \(sellOrderStatus.activeSellOrderStatus)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.secondaryText)
        }
        .padding(.horizontal, ResponsiveDesign.spacing(12))
        .padding(.vertical, ResponsiveDesign.spacing(8))
        .background(AppTheme.accentOrange.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(6))
    }

    private var sellButtonView: some View {
        Button(action: {
            showSellOrder = true
        }, label: {
            Text("VERKAUFEN")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#F5F5F5"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, ResponsiveDesign.spacing(12))
                .background(AppTheme.buttonColor)
                .cornerRadius(ResponsiveDesign.spacing(6))
        })
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Helper Methods
    private func openIssuerProductInfo(for holding: DepotHolding) {
        let wkn = holding.wkn
        let issuerCode = String(wkn.prefix(2))
        let productInfoURL = "https://www.\(issuerCode.lowercased()).com/products/\(wkn)"

        if let url = URL(string: productInfoURL) {
            UIApplication.shared.open(url)
        }

        print("🔍 Opening product info for WKN: \(wkn) at \(productInfoURL)")
    }

    private func toggleWatchlist() {
        Task {
            if services.traderService.isInWatchlist(holding.wkn) {
                try? await services.traderService.removeFromWatchlist(holding.wkn)
            } else {
                // Create a SearchResult from the holding for watchlist
                let searchResult = SearchResult(
                    valuationDate: holding.valuationDate,
                    wkn: holding.wkn,
                    strike: String(holding.strike),
                    askPrice: String(holding.currentPrice),
                    direction: holding.direction,
                    category: holding.direction,
                    underlyingType: nil,
                    isin: holding.wkn, // Use WKN as ISIN fallback
                    underlyingAsset: holding.underlyingAsset
                )
                try? await services.traderService.addToWatchlist(searchResult)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: ResponsiveDesign.spacing(16)) {
        // Partially sold example
        HoldingCard(
            holding: DepotHolding(
                orderId: "test-order-1",
                position: 1,
                valuationDate: "2024-01-15",
                wkn: "AAPL123",
                strike: 150.0,
                designation: "Apple Call Option",
                direction: "Call",
                underlyingAsset: "Apple Inc.",
                purchasePrice: 150.0,
                currentPrice: 160.0,
                quantity: 100,
                originalQuantity: 100,
                soldQuantity: 30, // Partially sold example
                remainingQuantity: 70,
                totalValue: 16000.0
            ),
            ongoingOrders: [],
            warrantDetailsViewModel: WarrantDetailsViewModel()
        )

        // Fully sold example
        HoldingCard(
            holding: DepotHolding(
                orderId: "test-order-2",
                position: 2,
                valuationDate: "2024-01-15",
                wkn: "TSLA456",
                strike: 200.0,
                designation: "Tesla Put Option",
                direction: "Put",
                underlyingAsset: "Tesla Inc.",
                purchasePrice: 200.0,
                currentPrice: 180.0,
                quantity: 50,
                originalQuantity: 50,
                soldQuantity: 50, // Fully sold
                remainingQuantity: 0,
                totalValue: 0.0
            ),
            ongoingOrders: [],
            warrantDetailsViewModel: WarrantDetailsViewModel()
        )
    }
    .padding()
    .background(AppTheme.screenBackground)
    .environment(\.appServices, .live)
}
