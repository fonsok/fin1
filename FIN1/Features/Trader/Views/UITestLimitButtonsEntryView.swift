import SwiftUI

#if DEBUG
/// Dedicated UI-test entry view that opens buy/sell order screens directly.
struct UITestLimitButtonsEntryView: View {
    enum Mode {
        case buy
        case sell
    }

    let services: AppServices
    let mode: Mode
    @State private var isPreparingSession = true
    @State private var preparationError: String?

    var body: some View {
        Group {
            if self.isPreparingSession {
                ProgressView()
                    .accessibilityIdentifier("UITestLimitEntryLoading")
            } else if self.preparationError != nil {
                Text(self.preparationError ?? "Unknown UI test setup error")
                    .accessibilityIdentifier("UITestLimitEntryError")
            } else {
                switch self.mode {
                case .buy:
                    BuyOrderViewWrapper(
                        searchResult: SearchResult(
                            valuationDate: "01.01.2026",
                            wkn: "846900",
                            strike: "100,00",
                            askPrice: "1,00",
                            direction: "Call",
                            category: "Optionsschein",
                            underlyingType: "Index",
                            isin: "DE0008469008",
                            underlyingAsset: "DAX",
                            denomination: 10,
                            subscriptionRatio: 0.1
                        ),
                        traderService: self.services.traderService,
                        cashBalanceService: self.services.cashBalanceService,
                        configurationService: self.services.configurationService,
                        investmentQuantityCalculationService: self.services.investmentQuantityCalculationService,
                        investmentService: self.services.investmentService,
                        userService: self.services.userService,
                        traderDataService: self.services.traderDataService,
                        auditLoggingService: self.services.auditLoggingService,
                        transactionLimitService: self.services.transactionLimitService
                    )
                    .accessibilityIdentifier("UITestDirectBuyOrderRoot")

                case .sell:
                    SellOrderViewWrapper(
                        holding: DepotHolding(
                            orderId: "UITEST-ORDER-1",
                            position: 1,
                            valuationDate: "01.01.2026",
                            wkn: "846900",
                            strike: 100.0,
                            designation: "Call - DAX",
                            direction: "Call",
                            underlyingAsset: "DAX",
                            purchasePrice: 1.0,
                            currentPrice: 1.0,
                            quantity: 100,
                            originalQuantity: 100,
                            soldQuantity: 0,
                            remainingQuantity: 100,
                            totalValue: 100.0,
                            denomination: 10,
                            subscriptionRatio: 0.1
                        ),
                        traderService: self.services.traderService,
                        userService: self.services.userService
                    )
                    .accessibilityIdentifier("UITestDirectSellOrderRoot")
                }
            }
        }
        .task { await self.prepareTraderSession() }
    }

    @MainActor
    private func prepareTraderSession() async {
        defer { isPreparingSession = false }
        if let user = services.userService.currentUser, user.role == .trader { return }
        do {
            try await self.services.userService.signIn(email: "trader1@test.com", password: TestConstants.password)
        } catch {
            self.preparationError = error.localizedDescription
        }
    }
}
#endif

