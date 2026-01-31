import SwiftUI

// MARK: - Collection Bill View Wrapper
/// Wrapper that properly manages ViewModel lifecycle with @StateObject
struct CollectionBillViewWrapper: View {
    let trade: TradeOverviewItem
    let document: Document?
    @StateObject private var viewModel: TradeStatementViewModel
    @Environment(\.appServices) private var services

    init(trade: TradeOverviewItem, document: Document? = nil) {
        self.trade = trade
        self.document = document
        self._viewModel = StateObject(wrappedValue: TradeStatementViewModel(trade: trade))
    }

    var body: some View {
        TradeStatementView(viewModel: viewModel, showCustomBackButton: true)
            .task {
                viewModel.attach(invoiceService: services.invoiceService, tradeService: services.tradeLifecycleService)
                // Set document number from document for accounting compliance
                viewModel.documentNumber = document?.accountingDocumentNumber
                // Force refresh to ensure latest calculation logic is applied
                viewModel.refreshDisplayData()
            }
    }
}
