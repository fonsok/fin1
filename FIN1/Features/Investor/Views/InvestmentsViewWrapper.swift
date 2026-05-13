import SwiftUI

// MARK: - Investments View Wrapper

struct InvestmentsViewWrapper: View {
    @Environment(\.appServices) private var services

    var body: some View {
        InvestmentsView(
            userService: self.services.userService,
            investmentService: self.services.investmentService,
            investorCashBalanceService: self.services.investorCashBalanceService,
            poolTradeParticipationService: self.services.poolTradeParticipationService,
            documentService: self.services.documentService,
            invoiceService: self.services.invoiceService,
            traderDataService: self.services.traderDataService,
            tradeLifecycleService: self.services.tradeLifecycleService,
            configurationService: self.services.configurationService,
            commissionCalculationService: self.services.commissionCalculationService,
            settlementAPIService: self.services.settlementAPIService
        )
    }
}

#Preview {
    InvestmentsViewWrapper()
        .environment(\.appServices, AppServices.live)
}
