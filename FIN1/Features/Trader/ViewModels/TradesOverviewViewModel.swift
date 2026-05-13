import Combine
import SwiftUI

// MARK: - Trades Overview View Model

@MainActor
final class TradesOverviewViewModel: ObservableObject {
    @Published var ongoingTrades: [TradeOverviewItem] = []
    @Published var completedTrades: [TradeOverviewItem] = []
    @Published var hasMoreTrades = true
    @Published var isLoading = false
    @Published var columnWidths: ColumnWidths?
    @Published var showDepot: Bool = false
    @Published var selectedTrade: TradeOverviewItem?
    @Published var showTradeDetails: Bool = false
    @Published var hasActiveTrade: Bool = false

    // Error handling
    @Published var errorMessage: String?
    @Published var showError = false

    /// Commission percentage string for display (e.g., "10%")
    var commissionPercentage: String {
        self.configurationService?.traderCommissionPercentage ?? "0%"
    }

    // Delegated ViewModels and Calculators
    let filteringViewModel: TradesOverviewFilteringViewModel
    var commissionCalculator: TradesOverviewCommissionCalculator

    nonisolated(unsafe) var cancellables = Set<AnyCancellable>()
    var orderService: (any OrderManagementServiceProtocol)?
    var tradeService: (any TradeLifecycleServiceProtocol)?
    var statisticsService: (any TradingStatisticsServiceProtocol)?
    var invoiceService: (any InvoiceServiceProtocol)?
    var configurationService: (any ConfigurationServiceProtocol)?
    var userService: (any UserServiceProtocol)?
    nonisolated(unsafe) var parseLiveQueryClient: (any ParseLiveQueryClientProtocol)?
    nonisolated(unsafe) var liveQuerySubscriptions: [LiveQuerySubscription] = []

    // Computed properties for filtered trades (delegate to filteringViewModel)
    var filteredOngoingTrades: [TradeOverviewItem] {
        self.filteringViewModel.filteredOngoingTrades
    }

    var filteredCompletedTrades: [TradeOverviewItem] {
        self.filteringViewModel.filteredCompletedTrades
    }

    var isCalculatingCommission: Bool {
        false // Commission calculation is now handled by calculator
    }

    init() {
        // Initialize filtering ViewModel
        self.filteringViewModel = TradesOverviewFilteringViewModel()

        // Initialize commission calculator (services will be injected via attach)
        self.commissionCalculator = TradesOverviewCommissionCalculator(
            invoiceService: nil,
            tradeService: nil,
            poolTradeParticipationService: nil,
            commissionCalculationService: nil,
            configurationService: nil
        )
    }

    // MARK: - Current Trader ID
    var currentTraderId: String? {
        self.userService?.currentUser?.id
    }

    deinit {
        let subs = liveQuerySubscriptions
        let client = parseLiveQueryClient
        liveQuerySubscriptions.removeAll()
        Task { @MainActor in
            for subscription in subs {
                client?.unsubscribe(subscription)
            }
        }
    }
}
