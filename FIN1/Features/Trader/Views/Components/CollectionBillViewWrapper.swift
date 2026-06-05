import SwiftUI

// MARK: - Collection Bill View Wrapper
/// Wrapper that properly manages ViewModel lifecycle with @StateObject
struct CollectionBillViewWrapper: View {
    let trade: TradeOverviewItem
    let document: Document?
    /// When the bill is opened before `TradeLifecycleService` has this trade in memory (Parse fetch in document flow).
    let fullTrade: Trade?
    /// True when opened from official Beleg snapshot — invoice view is for comparison only.
    let isInvoiceComparisonMode: Bool
    @StateObject private var viewModel: TradeStatementViewModel
    @Environment(\.appServices) private var services

    init(
        trade: TradeOverviewItem,
        document: Document? = nil,
        fullTrade: Trade? = nil,
        isInvoiceComparisonMode: Bool = false
    ) {
        self.trade = trade
        self.document = document
        self.fullTrade = fullTrade
        self.isInvoiceComparisonMode = isInvoiceComparisonMode
        self._viewModel = StateObject(wrappedValue: TradeStatementViewModel(trade: trade))
    }

    var body: some View {
        TradeStatementView(
            viewModel: self.viewModel,
            showCustomBackButton: true,
            isInvoiceComparisonMode: self.isInvoiceComparisonMode
        )
        .task {
            if let fullTrade = self.fullTrade {
                try? await self.services.invoiceService.loadInvoices(for: fullTrade.traderId)
                await self.services.invoiceService.generateInvoicesForCompletedTrades([fullTrade])
            } else if let uid = self.document?.userId, !uid.isEmpty {
                try? await self.services.invoiceService.loadInvoices(for: uid)
            }
            self.viewModel.attach(
                invoiceService: self.services.invoiceService,
                tradeService: self.services.tradeLifecycleService,
                prefetchedFullTrade: self.fullTrade
            )
            self.viewModel.documentNumber =
                self.document?.accountingDocumentNumber
                    ?? self.document?.documentNumber
            self.viewModel.refreshDisplayData()
        }
    }
}
