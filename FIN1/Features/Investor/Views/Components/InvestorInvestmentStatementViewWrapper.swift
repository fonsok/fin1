import SwiftUI

// MARK: - Investor Investment Statement View Wrapper

/// Owns the `InvestorInvestmentStatementViewModel` lifetime via `@StateObject`,
/// mirroring `CollectionBillViewWrapper` for the trader side.
///
/// Why this wrapper exists:
/// `CollectionBillDocumentView.body` re-evaluates multiple times during sheet
/// presentation (canonical document merge, services updates, sheet animation).
/// Constructing the statement ViewModel inline (`createInvestorStatementViewModel()`)
/// each time produced a fresh VM on every re-evaluation. The
/// `@ObservedObject` inside `InvestorInvestmentStatementView` then swapped to
/// the new (empty) VM while the in-flight backend refresh on the previous VM
/// finished writing `statementItems` into a now-unobserved instance — leaving
/// the items table visually empty even though the data had been fetched.
///
/// Owning the VM here as `@StateObject` ties its lifetime to the view's identity,
/// so SwiftUI never replaces it during body re-evaluations.
struct InvestorInvestmentStatementViewWrapper: View {
    let investment: Investment
    let documentNumber: String?

    @StateObject private var viewModel: InvestorInvestmentStatementViewModel

    init(investment: Investment, documentNumber: String?, services: AppServices) {
        self.investment = investment
        self.documentNumber = documentNumber
        _viewModel = StateObject(wrappedValue: InvestorInvestmentStatementViewModel(
            investment: investment,
            poolTradeParticipationService: services.poolTradeParticipationService,
            tradeService: services.tradeLifecycleService,
            invoiceService: services.invoiceService,
            configurationService: services.configurationService,
            settlementAPIService: services.settlementAPIService,
            statementDataProvider: InvestorInvestmentStatementDataProvider(
                parseAPIClient: services.parseAPIClient
            )
        ))
    }

    var body: some View {
        InvestorInvestmentStatementView(viewModel: self.viewModel)
            .task(id: self.documentNumber) {
                self.viewModel.documentNumber = self.documentNumber
            }
    }
}
