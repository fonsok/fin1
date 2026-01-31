import SwiftUI

// MARK: - Trade Details View Wrapper
/// Wrapper that properly manages ViewModel lifecycle with @StateObject
struct TradeDetailsViewWrapper: View {
    let trade: TradeOverviewItem
    @StateObject private var viewModel: TradeDetailsViewModel

    init(trade: TradeOverviewItem) {
        self.trade = trade
        self._viewModel = StateObject(wrappedValue: TradeDetailsViewModel(trade: trade))
    }

    var body: some View {
        TradeDetailsView(viewModel: viewModel)
    }
}
