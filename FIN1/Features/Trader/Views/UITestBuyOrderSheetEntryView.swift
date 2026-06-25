import SwiftUI

#if DEBUG
/// UI-test harness: opens buy order via `.sheet(item:)` + `BuyOrderViewWrapper` (same pattern as search results).
struct UITestBuyOrderSheetEntryView: View {
    let services: AppServices
    @State private var selectedResultForOrder: SearchResult?
    @State private var isPreparingSession = true
    @State private var preparationError: String?

    private let mockResult = SearchResult(
        valuationDate: "01.01.2026",
        wkn: "UITEST1",
        strike: "100,00",
        askPrice: "6,84",
        direction: "Put",
        category: "Optionsschein",
        underlyingType: "Index",
        isin: "DE000UITEST1",
        underlyingAsset: "NASDAQ 100",
        subscriptionRatio: 0.01
    )

    var body: some View {
        Group {
            if self.isPreparingSession {
                ProgressView()
                    .accessibilityIdentifier("UITestBuyOrderSheetEntryLoading")
            } else if let preparationError {
                Text(preparationError)
                    .accessibilityIdentifier("UITestBuyOrderSheetEntryError")
            } else {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    Text("UI-Test: Kauf-Sheet")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)
                    Button("KAUFEN") {
                        self.selectedResultForOrder = self.mockResult
                    }
                    .accessibilityIdentifier("UITestOpenBuyOrderSheetButton")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.screenBackground)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("UITestBuyOrderSheetEntryReady")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.screenBackground)
        .sheet(item: self.$selectedResultForOrder) { result in
            BuyOrderViewWrapper(searchResult: result, services: self.services)
                .accessibilityIdentifier("BuyOrderSheetRoot")
        }
        .task { await self.prepareTraderSessionIfNeeded() }
    }

    @MainActor
    private func prepareTraderSessionIfNeeded() async {
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
