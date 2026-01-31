import SwiftUI
import Combine

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
        configurationService?.traderCommissionPercentage ?? CalculationConstants.FeeRates.traderCommissionPercentage
    }

    // Delegated ViewModels and Calculators
    let filteringViewModel: TradesOverviewFilteringViewModel
    private var commissionCalculator: TradesOverviewCommissionCalculator

    private var cancellables = Set<AnyCancellable>()
    private var orderService: (any OrderManagementServiceProtocol)?
    private var tradeService: (any TradeLifecycleServiceProtocol)?
    private var statisticsService: (any TradingStatisticsServiceProtocol)?
    private var invoiceService: (any InvoiceServiceProtocol)?
    private var configurationService: (any ConfigurationServiceProtocol)?
    private var userService: (any UserServiceProtocol)?
    private var parseLiveQueryClient: (any ParseLiveQueryClientProtocol)?
    private var liveQuerySubscriptions: [LiveQuerySubscription] = []

    // Computed properties for filtered trades (delegate to filteringViewModel)
    var filteredOngoingTrades: [TradeOverviewItem] {
        filteringViewModel.filteredOngoingTrades
    }

    var filteredCompletedTrades: [TradeOverviewItem] {
        filteringViewModel.filteredCompletedTrades
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
    /// Returns the current trader's ID from the user service
    private var currentTraderId: String? {
        userService?.currentUser?.id
    }

    func attach(
        orderService: any OrderManagementServiceProtocol,
        tradeService: any TradeLifecycleServiceProtocol,
        statisticsService: any TradingStatisticsServiceProtocol,
        invoiceService: any InvoiceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)? = nil,
        commissionCalculationService: (any CommissionCalculationServiceProtocol)? = nil,
        investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)? = nil,
        userService: (any UserServiceProtocol)? = nil,
        parseLiveQueryClient: (any ParseLiveQueryClientProtocol)? = nil
    ) {
        // Attach once
        guard self.orderService == nil && self.tradeService == nil && self.statisticsService == nil && self.invoiceService == nil && self.configurationService == nil else { return }
        self.orderService = orderService
        self.tradeService = tradeService
        self.statisticsService = statisticsService
        self.invoiceService = invoiceService
        self.configurationService = configurationService
        self.userService = userService
        self.parseLiveQueryClient = parseLiveQueryClient

        // Update commission calculator with services
        self.commissionCalculator = TradesOverviewCommissionCalculator(
            invoiceService: invoiceService,
            tradeService: tradeService,
            poolTradeParticipationService: poolTradeParticipationService,
            commissionCalculationService: commissionCalculationService,
            configurationService: configurationService
        )

        // Observe active orders (show active trade when buy order reaches status 3: executed)
        orderService.activeOrdersPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.rebuildTrades()
                }
            }
            .store(in: &cancellables)

        // Observe completed trades (after sell completed and invoices created by notification service)
        tradeService.completedTradesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Read latest snapshots from services
                Task { @MainActor [weak self] in
                    await self?.rebuildTrades()
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to Live Query updates
        Task {
            await subscribeToLiveUpdates()
        }
        
        // Observe invoice changes (credit notes are added asynchronously after trade completion)
        // This ensures commission is updated when credit note becomes available
        NotificationCenter.default.publisher(for: .invoiceDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                // Check if a credit note was added
                if let invoiceType = notification.userInfo?["invoiceType"] as? String,
                   invoiceType == InvoiceType.creditNote.rawValue {
                    print("📄 TradesOverviewViewModel: Credit note added - refreshing trades to update commission")
                    Task { @MainActor [weak self] in
                        await self?.rebuildTrades()
                    }
                }
            }
            .store(in: &cancellables)

        // Observe role changes to reload trades for new trader
        NotificationCenter.default.publisher(for: .userDataDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("🔄 TradesOverviewViewModel: User data updated - reloading trades")
                Task { @MainActor [weak self] in
                    await self?.rebuildTrades()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("UserRoleChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("🔄 TradesOverviewViewModel: Role changed - reloading trades")
                Task { @MainActor [weak self] in
                    await self?.rebuildTrades()
                }
            }
            .store(in: &cancellables)

        // Initial load of trades when services are attached
        Task { @MainActor [weak self] in
            await self?.rebuildTrades()
        }
    }

    private func rebuildTrades() async {
        let (activeSnapshot, completedSnapshot) = getTradeSnapshots()
        self.hasActiveTrade = detectActiveTrade(activeSnapshot, completedSnapshot)

        let (ongoingItems, completedItems) = await processTrades(completedSnapshot)

        // Update local trade lists (for sorting)
        updateTradeLists(ongoingItems, completedItems)

        // Update the filtering ViewModel with the sorted trades
        filteringViewModel.updateTrades(ongoing: ongoingTrades, completed: completedTrades)

        // Apply default filter (last30Days) to display trades immediately
        await filteringViewModel.filterTrades(by: .last30Days)

        // Recalculate column widths when data changes
        let tableRows = createTableRows(from: filteringViewModel.filteredCompletedTrades)
        self.columnWidths = ColumnWidthCalculator.calculate(for: tableRows)
    }

    // MARK: - Rebuild Trades Helpers

    private func getTradeSnapshots() -> ([Order], [Trade]) {
        // CRITICAL: Filter by current trader ID to ensure trade isolation
        // Each trader should only see their own trades
        guard let traderId = currentTraderId else {
            print("⚠️ TradesOverviewViewModel: No current trader ID - returning empty snapshots")
            return ([], [])
        }

        let activeSnapshot = (orderService?.activeOrders ?? [])
            .filter { $0.traderId == traderId }
        let completedSnapshot = (tradeService?.completedTrades ?? [])
            .filter { $0.traderId == traderId }

        return (activeSnapshot, completedSnapshot)
    }

    private func detectActiveTrade(_ activeSnapshot: [Order], _ completedSnapshot: [Trade]) -> Bool {
        let activeBuys = activeSnapshot.contains { $0.type == .buy && $0.buyStatus == .executed }
        // Use the already-filtered completedSnapshot instead of accessing all trades
        let hasPendingOrActiveTrade = completedSnapshot.contains { !$0.isCompleted } || activeBuys
        return hasPendingOrActiveTrade
    }

    private func processTrades(_ trades: [Trade]) async -> ([TradeOverviewItem], [TradeOverviewItem]) {
        var ongoingItems: [TradeOverviewItem] = []
        var completedItems: [TradeOverviewItem] = []

        for trade in trades {
            let item = await createTradeOverviewItem(for: trade)

            if trade.isCompleted {
                completedItems.append(item)
            } else {
                ongoingItems.append(item)
            }
        }

        return (ongoingItems, completedItems)
    }

    private func createTradeOverviewItem(for trade: Trade) async -> TradeOverviewItem {
        // Use Trade.displayProfit as SINGLE SOURCE OF TRUTH for profit display
        // This ensures Profit value and ROI percentage always use consistent calculation
        let pnl = trade.displayProfit
        let roi = trade.displayROI
        let endDate = trade.completedAt ?? Date()
        let startDate = trade.createdAt

        // Note: grossProfit is NOT the same as displayProfit
        // displayProfit = net profit (after fees), grossProfit = before fees
        // For display purposes, we use displayProfit
        let totalFees = calculateInvoiceBasedFees(for: trade)

        // Calculate commission using centralized calculator
        // Commission is calculated from investor gross profits (not trade net profit)
        // Commission is only paid when there are investors participating
        let commission = await commissionCalculator.calculateCommission(tradeId: trade.id, hasProfit: pnl > 0)

        return TradeOverviewItem(
            tradeId: trade.id,
            tradeNumber: trade.tradeNumber,
            startDate: startDate,
            endDate: endDate,
            profitLoss: pnl,
            returnPercentage: roi,
            commission: commission,
            isActive: !trade.isCompleted,
            statusText: trade.status.displayName,
            statusDetail: trade.status.displayName,
            onDetailsTapped: { [weak self] in
                Task { @MainActor [weak self] in
                    await self?.handleTradeDetailsTapped(
                        trade: trade,
                        grossProfit: pnl,  // Use displayProfit for display (net profit)
                        totalFees: totalFees,
                        pnl: pnl,
                        roi: roi,
                        startDate: startDate,
                        endDate: endDate,
                        commission: commission
                    )
                }
            },
            grossProfit: pnl,  // Use displayProfit for display (net profit)
            totalFees: totalFees
        )
    }

    private func handleTradeDetailsTapped(
        trade: Trade,
        grossProfit: Double,
        totalFees: Double,
        pnl: Double,
        roi: Double,
        startDate: Date,
        endDate: Date,
        commission: Double
    ) async {
        let detailsCommission = await commissionCalculator.calculateCommission(tradeId: trade.id, hasProfit: pnl > 0)
        selectedTrade = TradeOverviewItem(
            tradeId: trade.id,
            tradeNumber: trade.tradeNumber,
            startDate: startDate,
            endDate: endDate,
            profitLoss: pnl,
            returnPercentage: roi,
            commission: detailsCommission,
            isActive: !trade.isCompleted,
            statusText: trade.status.displayName,
            statusDetail: trade.status.displayName,
            onDetailsTapped: {},
            grossProfit: grossProfit,
            totalFees: totalFees
        )
        showTradeDetails = true
    }

    private func updateTradeLists(_ ongoingItems: [TradeOverviewItem], _ completedItems: [TradeOverviewItem]) {
        // Sort ongoing trades by recency (most recent first)
        self.ongoingTrades = ongoingItems.sorted { $0.endDate > $1.endDate }
        // Sort completed trades by trade number (descending) - most recent trades (highest numbers) on top
        // This ensures trade numbers 3, 2, 1... are displayed with newest first
        self.completedTrades = completedItems.sorted { $0.tradeNumber > $1.tradeNumber }
    }

    func filterTrades(by period: TradeTimePeriod) async {
        isLoading = true
        try? await Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000)) // Simulate filtering delay

        // Update filtering ViewModel with current trades
        filteringViewModel.updateTrades(ongoing: ongoingTrades, completed: completedTrades)

        // Delegate filtering to filteringViewModel
        await filteringViewModel.filterTrades(by: period)

        // Recalculate column widths when data changes (use completed trades for table)
        let tableRows = createTableRows(from: filteringViewModel.filteredCompletedTrades)
        self.columnWidths = ColumnWidthCalculator.calculate(for: tableRows)

        isLoading = false
    }

    // MARK: - Data Transformation Methods

    /// Creates table row data from completed trades (business logic)
    /// Uses stored trade numbers from the Trade model (per-trader sequential numbering)
    /// Trades should already be sorted by tradeNumber before calling this method
    func createTableRows(from trades: [TradeOverviewItem]) -> [TradeTableRowData] {
        // Use stored trade numbers (don't pass displayNumber to use trade.tradeNumber)
        // This ensures trade numbers match what was stored when trades were created
        return trades.map { trade in
            TradeTableRowData(from: trade, displayNumber: nil)
        }
    }


    // MARK: - Profit Calculation Helpers

    private func calculateGrossProfit(for trade: Trade) -> Double {
        return statisticsService?.calculateGrossProfit(for: trade) ?? 0.0
    }

    private func calculateTotalFees(for trade: Trade) -> Double {
        return statisticsService?.calculateTotalFees(for: trade) ?? 0.0
    }

    // MARK: - Invoice-Based Calculation (Single Source of Truth)

    private func calculateInvoiceBasedProfit(for trade: Trade) -> Double {
        // Use invoice-based calculation as single source of truth
        // This ensures consistency with Collection Bill
        guard let invoiceService = invoiceService else { return 0.0 }

        // Get all invoices for this trade
        let allInvoices = invoiceService.getInvoicesForTrade(trade.id)
        let buyInvoices = allInvoices.filter { $0.transactionType == .buy }
        let sellInvoices = allInvoices.filter { $0.transactionType == .sell }

        // Use the first buy invoice (there should only be one)
        let buyInvoice = buyInvoices.first

        return ProfitCalculationService.calculateTaxableProfit(buyInvoice: buyInvoice, sellInvoices: sellInvoices)
    }

    private func calculateInvoiceBasedFees(for trade: Trade) -> Double {
        // Calculate fees from invoices as single source of truth
        guard let invoiceService = invoiceService else { return 0.0 }

        // Get all invoices for this trade
        let allInvoices = invoiceService.getInvoicesForTrade(trade.id)

        return allInvoices.reduce(0) { $0 + $1.feesTotal }
    }


    // MARK: - Error Handling

    func clearError() {
        errorMessage = nil
        showError = false
    }

    func showError(_ message: String) {
        errorMessage = message
        showError = true
    }

    func showError(_ error: AppError) {
        errorMessage = error.errorDescription ?? "An error occurred"
        showError = true
    }

    func handleError(_ error: Error) {
        let appError = error.toAppError()
        errorMessage = appError.errorDescription ?? "An error occurred"
        showError = true
    }
    
    // MARK: - Live Query Integration
    
    private func subscribeToLiveUpdates() async {
        guard let liveQueryClient = parseLiveQueryClient,
              let traderId = currentTraderId else {
            return
        }
        
        // Subscribe to Order updates for current trader
        let orderSubscription = liveQueryClient.subscribe(
            className: "Order",
            query: ["traderId": traderId],
            onUpdate: { [weak self] (parseOrder: ParseOrder) in
                Task { @MainActor [weak self] in
                    // Rebuild trades when order is updated
                    await self?.rebuildTrades()
                }
            },
            onDelete: { [weak self] (_ objectId: String) in
                Task { @MainActor [weak self] in
                    // Rebuild trades when order is deleted
                    await self?.rebuildTrades()
                }
            },
            onError: { error in
                print("⚠️ Live Query error for Order: \(error.localizedDescription)")
            }
        )
        liveQuerySubscriptions.append(orderSubscription)
        
        // Subscribe to Trade updates for current trader
        let tradeSubscription = liveQueryClient.subscribe(
            className: "Trade",
            query: ["traderId": traderId],
            onUpdate: { [weak self] (parseTrade: ParseTrade) in
                Task { @MainActor [weak self] in
                    // Rebuild trades when trade is updated
                    await self?.rebuildTrades()
                }
            },
            onDelete: { [weak self] (_ objectId: String) in
                Task { @MainActor [weak self] in
                    // Rebuild trades when trade is deleted
                    await self?.rebuildTrades()
                }
            },
            onError: { error in
                print("⚠️ Live Query error for Trade: \(error.localizedDescription)")
            }
        )
        liveQuerySubscriptions.append(tradeSubscription)
    }
    
    deinit {
        // Unsubscribe from Live Query
        for subscription in liveQuerySubscriptions {
            parseLiveQueryClient?.unsubscribe(subscription)
        }
        liveQuerySubscriptions.removeAll()
    }
}
