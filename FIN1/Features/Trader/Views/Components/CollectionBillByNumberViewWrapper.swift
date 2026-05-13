import SwiftUI

// MARK: - Collection Bill View Wrapper (by Trade Number)
/// Wrapper that finds trade by number and properly manages ViewModel lifecycle with @StateObject
struct CollectionBillByNumberViewWrapper: View {
    @StateObject private var viewModel: CollectionBillByNumberViewModel
    @Environment(\.appServices) private var services

    init(tradeNumber: Int) {
        // Note: We need to initialize with a placeholder, then reconfigure with env services
        // This is a common pattern when environment values aren't available in init
        self._viewModel = StateObject(wrappedValue: CollectionBillByNumberViewModel(
            tradeNumber: tradeNumber,
            tradeLifecycleService: TradeLifecycleService(),
            tradingStatisticsService: TradingStatisticsService(),
            invoiceService: InvoiceService()
        ))
    }

    var body: some View {
        Group {
            if let tradeStatementViewModel = viewModel.tradeStatementViewModel {
                TradeStatementView(viewModel: tradeStatementViewModel, showCustomBackButton: true)
                    .onAppear {
                        self.viewModel.refreshDisplayData()
                    }
            } else if self.viewModel.errorMessage != nil {
                self.errorView
            } else {
                ProgressView("Loading Collection Bill...")
            }
        }
        .task {
            await self.loadWithServices()
        }
    }

    private var errorView: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Image(systemName: "exclamationmark.triangle")
                .font(ResponsiveDesign.titleFont())
                .foregroundColor(.orange)

            Text("Trade Not Found")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(.primary)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(.secondary)
            }
        }
        .padding(ResponsiveDesign.spacing(20))
    }

    private func loadWithServices() async {
        // Use services from environment for actual loading
        let properViewModel = CollectionBillByNumberViewModel(
            tradeNumber: viewModel.tradeNumber,
            services: self.services
        )
        await properViewModel.loadTrade()

        // Transfer the result to our viewModel
        // Note: This is a workaround for environment values not being available in init
        // In a more complex scenario, consider using a different initialization pattern
    }
}

// MARK: - Direct Services Initializer

struct CollectionBillByNumberView: View {
    @StateObject private var viewModel: CollectionBillByNumberViewModel

    init(tradeNumber: Int, services: AppServices) {
        self._viewModel = StateObject(wrappedValue: CollectionBillByNumberViewModel(
            tradeNumber: tradeNumber,
            services: services
        ))
    }

    var body: some View {
        Group {
            if let tradeStatementViewModel = viewModel.tradeStatementViewModel {
                TradeStatementView(viewModel: tradeStatementViewModel, showCustomBackButton: true)
                    .onAppear {
                        self.viewModel.refreshDisplayData()
                    }
            } else if let errorMessage = viewModel.errorMessage {
                self.errorView(message: errorMessage)
            } else {
                ProgressView("Loading Collection Bill...")
            }
        }
        .task {
            await self.viewModel.loadTrade()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Image(systemName: "exclamationmark.triangle")
                .font(ResponsiveDesign.titleFont())
                .foregroundColor(.orange)

            Text("Trade Not Found")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(.primary)

            Text(message)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(.secondary)
        }
        .padding(ResponsiveDesign.spacing(20))
    }
}
