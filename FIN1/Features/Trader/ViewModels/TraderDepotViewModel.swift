import Foundation
import SwiftUI
import Combine

@MainActor
final class TraderDepotViewModel: ObservableObject {
    @Published var depotValue: Double = 0
    @Published var depotNumber: String = ""
    @Published var ongoingOrders: [Order] = []
    @Published var holdings: [DepotHolding] = []
    @Published var allHoldings: [DepotHolding] = [] // All holdings including those being sold
    @Published var completedSellOrders: [Order] = [] // Track completed sell orders to prevent holdings from reappearing

    private let traderService: any TraderServiceProtocol
    private let documentService: any DocumentServiceProtocol
    private let testModeService: any TestModeServiceProtocol
    private let userService: (any UserServiceProtocol)?
    private let holdingsConversionService: HoldingsConversionServiceProtocol
    private nonisolated(unsafe) let parseLiveQueryClient: (any ParseLiveQueryClientProtocol)?
    private nonisolated(unsafe) var cancellables = Set<AnyCancellable>()
    private nonisolated(unsafe) var liveQuerySubscriptions: [LiveQuerySubscription] = []

    // MARK: - Current Trader ID
    /// Returns the current trader's ID from the user service
    private var currentTraderId: String? {
        userService?.currentUser?.id
    }

    init(
        traderService: any TraderServiceProtocol,
        documentService: any DocumentServiceProtocol,
        testModeService: any TestModeServiceProtocol,
        userService: (any UserServiceProtocol)? = nil,
        holdingsConversionService: HoldingsConversionServiceProtocol = HoldingsConversionService.shared,
        parseLiveQueryClient: (any ParseLiveQueryClientProtocol)? = nil
    ) {
        self.traderService = traderService
        self.documentService = documentService
        self.testModeService = testModeService
        self.userService = userService
        self.holdingsConversionService = holdingsConversionService
        self.parseLiveQueryClient = parseLiveQueryClient
        print("🔍 DEBUG: TraderDepotViewModel init - traderService instance: \(ObjectIdentifier(traderService as AnyObject))")
        print("🔍 DEBUG: TraderDepotViewModel init - initial activeOrders count: \(traderService.activeOrders.count)")
        // Ensure service is running for test simulation
        (self.traderService as? ServiceLifecycle)?.start()
        loadData()
        bindService()
        Task { [weak self] in
            try? await self?.traderService.loadAllTradingData()
            await self?.subscribeToLiveUpdates()
        }
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
        cancellables.removeAll()
        print("🧹 TraderDepotViewModel deallocated")
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
                Task { @MainActor in
                    // Reload data when order is updated
                    try? await self?.traderService.loadAllTradingData()
                    self?.loadData()
                }
            },
            onDelete: { [weak self] (_ objectId: String) in
                Task { @MainActor in
                    // Reload data when order is deleted
                    try? await self?.traderService.loadAllTradingData()
                    self?.loadData()
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
                Task { @MainActor in
                    // Reload data when trade is updated
                    try? await self?.traderService.loadAllTradingData()
                    self?.loadData()
                }
            },
            onDelete: { [weak self] (_ objectId: String) in
                Task { @MainActor in
                    // Reload data when trade is deleted
                    try? await self?.traderService.loadAllTradingData()
                    self?.loadData()
                }
            },
            onError: { error in
                print("⚠️ Live Query error for Trade: \(error.localizedDescription)")
            }
        )
        liveQuerySubscriptions.append(tradeSubscription)
    }

    private func bindService() {
        traderService.activeOrdersPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (orders: [Order]) in
                guard let self else { return }
                // CRITICAL: Filter by current trader ID to ensure order isolation
                let filteredOrders = self.filterOrdersByCurrentTrader(orders)
                print("🔍 DEBUG: TraderDepotViewModel received \(orders.count) active orders, \(filteredOrders.count) for current trader")
                self.ongoingOrders = filteredOrders
                // Refresh holdings to account for any executed/confirmed orders
                self.refreshHoldingsFromOngoingOrders()
            }
            .store(in: &cancellables)

        // Listen for completed sell orders
        NotificationCenter.default.publisher(for: .sellOrderCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let order = notification.userInfo?["order"] as? Order {
                    self?.addCompletedSellOrder(order)
                } else if notification.object is Trade {
                    // Handle trade-based notification (from TradingNotificationService)
                    print("🔍 DEBUG: Received sell order completed notification with Trade object")
                    self?.refreshHoldingsFromOngoingOrders()
                }
            }
            .store(in: &cancellables)

        // For now, we'll create holdings from completed orders directly
        // In a real app, this would come from a completed orders service
        traderService.completedTradesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] trades in
                guard let self else { return }
                // CRITICAL: Filter by current trader ID to ensure trade isolation
                let filteredTrades = self.filterTradesByCurrentTrader(trades)
                print("🔍 DEBUG: TraderDepotViewModel received \(trades.count) completed trades, \(filteredTrades.count) for current trader")
                var positionCounter = 1
                // Architecture: Convert completed Orders to DepotHolding (holdings)
                // This represents the final state after buy orders are completed
                self.allHoldings = filteredTrades.map { trade in
                    defer { positionCounter += 1 }
                    return self.createHoldingFromTrade(trade, position: positionCounter)
                }
                self.updateFilteredHoldings()
            }
            .store(in: &cancellables)
    }

    func loadData() {
        // Use mock depot number for now (can be wired to real data later)
        self.depotNumber = mockDepotNumber

        // Initial snapshot - filter by current trader ID
        self.ongoingOrders = filterOrdersByCurrentTrader(traderService.activeOrders)
        var pos = 1
        // Architecture: Convert completed Orders to DepotHolding (holdings)
        // This represents the final state after buy orders are completed
        let filteredTrades = filterTradesByCurrentTrader(traderService.completedTrades)
        self.allHoldings = filteredTrades.map { trade in
            defer { pos += 1 }
            return self.createHoldingFromTrade(trade, position: pos)
        }
        self.updateFilteredHoldings()
    }

    // MARK: - Trade Filtering Helpers

    /// Filters trades to only include those belonging to the current trader
    private func filterTradesByCurrentTrader(_ trades: [Trade]) -> [Trade] {
        guard let traderId = currentTraderId else {
            print("⚠️ TraderDepotViewModel: No current trader ID - returning empty trades")
            return []
        }
        return trades.filter { $0.traderId == traderId }
    }

    /// Filters orders to only include those belonging to the current trader
    private func filterOrdersByCurrentTrader(_ orders: [Order]) -> [Order] {
        guard let traderId = currentTraderId else {
            print("⚠️ TraderDepotViewModel: No current trader ID - returning empty orders")
            return []
        }
        return orders.filter { $0.traderId == traderId }
    }

    /// Creates a DepotHolding from a trade, accounting for partial sales
    /// Uses centralized HoldingsConversionService as SINGLE SOURCE OF TRUTH
    private func createHoldingFromTrade(_ trade: Trade, position: Int) -> DepotHolding {
        return holdingsConversionService.createHolding(
            from: trade,
            position: position,
            ongoingOrders: ongoingOrders
        )
    }

    private func updateFilteredHoldings() {
        // Filter holdings based on partial sales status
        // Only show holdings that are not fully sold
        self.holdings = allHoldings.filter { holding in
            // Show holdings that still have remaining quantity available for selling
            return holding.remainingQuantity > 0
        }

        print("🔍 DEBUG: updateFilteredHoldings - allHoldings: \(allHoldings.count), filtered holdings: \(holdings.count)")
        recalculateDepotValue()
    }

    // MARK: - Public Methods for External Updates

    func addCompletedSellOrder(_ order: Order) {
        // Add completed sell order to prevent holdings from reappearing
        completedSellOrders.append(order)

        // Force refresh of holdings to get updated trade data
        refreshHoldingsFromOngoingOrders()

        print("🔍 DEBUG: Added completed sell order \(order.id) to completedSellOrders. Total: \(completedSellOrders.count)")
        print("🔍 DEBUG: Order details - Symbol: \(order.symbol), Quantity: \(order.quantity), Status: \(order.status)")
    }

    /// Updates holdings when a partial sell order is executed
    func updateHoldingForPartialSale(holdingId: String, soldQuantity: Int) {
        // Find the holding and update it with the partial sale
        if let index = allHoldings.firstIndex(where: { $0.id.uuidString == holdingId }) {
            allHoldings[index] = allHoldings[index].withPartialSale(soldQuantity: soldQuantity)
            updateFilteredHoldings()
            print("🔍 DEBUG: Updated holding \(holdingId) with partial sale of \(soldQuantity) units")
        }
    }

    /// Refreshes holdings data from the trader service
    func refreshHoldings() {
        loadData()
    }

    /// Refreshes holdings to account for executed/confirmed ongoing orders
    private func refreshHoldingsFromOngoingOrders() {
        // Recreate all holdings with updated ongoing orders - filter by current trader
        var pos = 1
        let filteredTrades = filterTradesByCurrentTrader(traderService.completedTrades)
        print("🔍 DEBUG: refreshHoldingsFromOngoingOrders - completedTrades count: \(filteredTrades.count) (filtered for current trader)")
        self.allHoldings = filteredTrades.map { trade in
            defer { pos += 1 }
            return self.createHoldingFromTrade(trade, position: pos)
        }
        self.updateFilteredHoldings()
        print("🔍 DEBUG: Refreshed holdings from ongoing orders - total holdings: \(allHoldings.count)")
    }

    /// Recalculates the depot's total value (Gesamtwert) based on current holdings.
    private func recalculateDepotValue() {
        let total = holdings.reduce(0.0) { partial, holding in
            partial + (Double(holding.remainingQuantity) * holding.currentPrice)
        }
        depotValue = total
    }
}
