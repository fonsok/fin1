import SwiftUI

// MARK: - Holding Card
/// Displays individual holding information with sell functionality
struct HoldingCard: View {
    let holding: DepotHolding
    let ongoingOrders: [Order]
    @ObservedObject var warrantDetailsViewModel: WarrantDetailsViewModel
    let onKaufenTapped: () -> Void
    @Environment(\.appServices) private var services
    @State private var showSellOrder = false
    @State private var showAdditionalDetails = false
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        CardContainer(
            position: self.holding.position,
            showWatchlistIcon: false,
            isInWatchlist: self.services.traderService.isInWatchlist(self.holding.wkn),
            onPapersheetTapped: {
                self.openIssuerProductInfo(for: self.holding)
            },
            onWatchlistTapped: {
                self.toggleWatchlist()
            },
            chevronButton: {
                AnyView(
                    Button(action: {
                        self.showAdditionalDetails.toggle()
                    }, label: {
                        Image(systemName: self.showAdditionalDetails ? "chevron.up" : "chevron.down")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.secondaryText)
                    })
                    .buttonStyle(PlainButtonStyle())
                )
            }
        ) {
            VStack(spacing: ResponsiveDesign.spacing(8)) {
                // Show partial sales progress if applicable
                if self.holding.isPartiallySold {
                    self.partialSalesProgressView
                }

                // Main content grid using TileGrid
                TileGrid(
                    tiles: HoldingCardTiles.generateTiles(
                        for: self.holding,
                        showAdditionalDetails: self.showAdditionalDetails,
                        warrantDetailsViewModel: self.warrantDetailsViewModel,
                        poolStatusDisplay: self.poolStatusDisplay
                    ),
                    columns: 2
                )

                // Buy / sell actions
                self.tradeActionView
            }
        }
        .sheet(isPresented: self.$showSellOrder) {
            SellOrderViewWrapper(
                holding: self.holding,
                traderService: self.services.traderService,
                userService: self.services.userService,
                maxPartialSells: self.services.configurationService.effectiveMaxTraderPartialSells
            )
        }
    }

    private var poolStatusDisplay: String? {
        guard self.services.configurationService.showTraderDashboardInvestmentActiveStatus else {
            return nil
        }
        return DepotPositionPoolStatusResolver.displayValue(
            for: self.holding,
            completedTrades: self.services.traderService.completedTrades,
            participations: self.services.poolTradeParticipationService.participations
        )
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
                Text("Sold: \(self.holding.soldQuantity)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.secondaryText)
                Spacer()
                Text("Remaining: \(self.holding.remainingQuantity)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.secondaryText)
            }

            ProgressView(value: Double(self.holding.soldQuantity), total: Double(self.holding.originalQuantity))
                .progressViewStyle(LinearProgressViewStyle(tint: AppTheme.accentLightBlue))
        }
        .padding(.horizontal, ResponsiveDesign.spacing(12))
        .padding(.vertical, ResponsiveDesign.spacing(8))
        .background(AppTheme.accentLightBlue.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(6))
    }

    // MARK: - Trade Action View
    private var tradeActionView: some View {
        let sellOrderStatus = HoldingSellOrderStatus(holding: holding, ongoingOrders: ongoingOrders)

        if self.holding.remainingQuantity <= 0 {
            return AnyView(
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    self.fullySoldInfoView
                    self.kaufenButtonView
                }
            )
        } else if sellOrderStatus.hasActiveSellOrder {
            return AnyView(
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    self.activeSellOrderView(sellOrderStatus)
                    self.kaufenButtonView
                }
            )
        } else {
            return AnyView(
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    self.kaufenButtonView
                    self.sellButtonView
                }
            )
        }
    }

    private var kaufenButtonView: some View {
        Button(action: self.onKaufenTapped, label: {
            Text("KAUFEN")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ResponsiveDesign.spacing(12))
                .background(AppTheme.buttonColor)
                .cornerRadius(ResponsiveDesign.spacing(6))
        })
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("KaufenButton_\(self.holding.wkn)")
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
            self.showSellOrder = true
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
            if self.services.traderService.isInWatchlist(self.holding.wkn) {
                try? await self.services.traderService.removeFromWatchlist(self.holding.wkn)
            } else {
                let searchResult = SearchResult(depotHolding: self.holding)
                try? await self.services.traderService.addToWatchlist(searchResult)
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
                totalValue: 16_000.0
            ),
            ongoingOrders: [],
            warrantDetailsViewModel: WarrantDetailsViewModel(),
            onKaufenTapped: {}
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
            warrantDetailsViewModel: WarrantDetailsViewModel(),
            onKaufenTapped: {}
        )
    }
    .padding()
    .background(AppTheme.screenBackground)
    .environment(\.appServices, .live)
}
