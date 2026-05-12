import SwiftUI

// MARK: - Investments View Wrapper

struct InvestmentsViewWrapper: View {
    @Environment(\.appServices) private var services

    var body: some View {
        InvestmentsView(
            userService: services.userService,
            investmentService: services.investmentService,
            investorCashBalanceService: services.investorCashBalanceService,
            poolTradeParticipationService: services.poolTradeParticipationService,
            documentService: services.documentService,
            invoiceService: services.invoiceService,
            traderDataService: services.traderDataService,
            tradeLifecycleService: services.tradeLifecycleService,
            configurationService: services.configurationService,
            commissionCalculationService: services.commissionCalculationService,
            settlementAPIService: services.settlementAPIService
        )
    }
}

#Preview {
    InvestmentsViewWrapper()
        .environment(\.appServices, AppServices.live)
}
