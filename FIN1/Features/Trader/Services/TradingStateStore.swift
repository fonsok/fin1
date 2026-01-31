import Foundation
import Combine

// MARK: - Trading State Store Protocol
/// Centralized state management for all trading-related data
@MainActor
protocol TradingStateStoreProtocol: ObservableObject {
    // MARK: - Published Properties
    var holdings: [DepotHolding] { get }
    var activeOrders: [Order] { get }
    var completedTrades: [Trade] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // MARK: - Publishers
    var holdingsPublisher: AnyPublisher<[DepotHolding], Never> { get }
    var activeOrdersPublisher: AnyPublisher<[Order], Never> { get }
    var completedTradesPublisher: AnyPublisher<[Trade], Never> { get }

    // MARK: - State Operations
    func updateHoldings(_ holdings: [DepotHolding])
    func updateActiveOrders(_ orders: [Order])
    func updateCompletedTrades(_ trades: [Trade])
    func addOrder(_ order: Order)
    func removeOrder(_ orderId: String)
    func updateOrder(_ order: Order)
    func addTrade(_ trade: Trade)
    func updateTrade(_ trade: Trade)
    func setLoading(_ isLoading: Bool)
    func setError(_ error: String?)
    func clearError()
}

// MARK: - Trading State Store Implementation
@MainActor
final class TradingStateStore: TradingStateStoreProtocol {
    // MARK: - Dependencies
    private let holdingsConversionService: HoldingsConversionServiceProtocol

    // MARK: - Published Properties
    @Published var holdings: [DepotHolding] = []
    @Published var activeOrders: [Order] = []
    @Published var completedTrades: [Trade] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    init(holdingsConversionService: HoldingsConversionServiceProtocol = HoldingsConversionService.shared) {
        self.holdingsConversionService = holdingsConversionService
    }

    // MARK: - Publishers
    var holdingsPublisher: AnyPublisher<[DepotHolding], Never> {
        $holdings.eraseToAnyPublisher()
    }

    var activeOrdersPublisher: AnyPublisher<[Order], Never> {
        $activeOrders.eraseToAnyPublisher()
    }

    var completedTradesPublisher: AnyPublisher<[Trade], Never> {
        $completedTrades.eraseToAnyPublisher()
    }

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    // Default initializer - uses default service parameter
    // This is safe because HoldingsConversionService.shared is a thread-safe singleton

    // MARK: - State Operations
    func updateHoldings(_ holdings: [DepotHolding]) {
        self.holdings = holdings
    }

    func updateActiveOrders(_ orders: [Order]) {
        self.activeOrders = orders
    }

    func updateCompletedTrades(_ trades: [Trade]) {
        self.completedTrades = trades
        // Automatically update holdings when trades change
        updateHoldingsFromTrades()
    }

    func addOrder(_ order: Order) {
        activeOrders.append(order)
    }

    func removeOrder(_ orderId: String) {
        activeOrders.removeAll { $0.id == orderId }
    }

    func updateOrder(_ order: Order) {
        if let index = activeOrders.firstIndex(where: { $0.id == order.id }) {
            activeOrders[index] = order
        }
    }

    func addTrade(_ trade: Trade) {
        completedTrades.append(trade)
        updateHoldingsFromTrades()
    }

    func updateTrade(_ trade: Trade) {
        if let index = completedTrades.firstIndex(where: { $0.id == trade.id }) {
            completedTrades[index] = trade
            updateHoldingsFromTrades()
        }
    }

    func setLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }

    func setError(_ error: String?) {
        self.errorMessage = error
    }

    func clearError() {
        self.errorMessage = nil
    }

    // MARK: - Private Methods
    private func setupStateObservers() {
        // Observe completed trades changes to automatically update holdings
        $completedTrades
            .sink { [weak self] _ in
                self?.updateHoldingsFromTrades()
            }
            .store(in: &cancellables)
    }

    private func updateHoldingsFromTrades() {
        var positionCounter = 1
        let newHoldings = completedTrades.map { trade in
            defer { positionCounter += 1 }
            return createHoldingFromTrade(trade, position: positionCounter)
        }

        // Apply ongoing orders to holdings
        let updatedHoldings = newHoldings.map { holding in
            applyOngoingOrdersToHolding(holding)
        }

        holdings = updatedHoldings.filter { $0.remainingQuantity > 0 }
    }

    /// Creates a DepotBestand from a trade, accounting for partial sales
    /// Uses centralized HoldingsConversionService as SINGLE SOURCE OF TRUTH
    private func createHoldingFromTrade(_ trade: Trade, position: Int) -> DepotHolding {
        return holdingsConversionService.createHolding(
            from: trade,
            position: position,
            ongoingOrders: activeOrders
        )
    }

    private func applyOngoingOrdersToHolding(_ holding: DepotHolding) -> DepotHolding {
        // Find executed ongoing orders for this holding
        let executedOngoingOrders = activeOrders.filter { order in
            guard order.type == .sell else { return false }

            // Check if this order belongs to this holding
            let belongsToHolding = order.originalHoldingId == holding.orderId ||
                                  order.originalHoldingId == holding.wkn ||
                                  order.symbol == holding.wkn

            // Check if order is in executed or confirmed status
            let isExecutedOrConfirmed = order.sellStatus == .executed || order.sellStatus == .confirmed

            return belongsToHolding && isExecutedOrConfirmed
        }

        // Apply executed ongoing orders to the holding
        if !executedOngoingOrders.isEmpty {
            let executedQuantity = executedOngoingOrders.reduce(0) { $0 + Int($1.quantity) }
            return holding.withPartialSale(soldQuantity: executedQuantity)
        }

        return holding
    }
}

// MARK: - Trading State Store Extensions
extension TradingStateStore {
    /// Computed property for filtered holdings (only those with remaining quantity)
    var availableHoldings: [DepotHolding] {
        holdings.filter { $0.remainingQuantity > 0 }
    }

    /// Computed property for all holdings (including fully sold)
    var allHoldings: [DepotHolding] {
        holdings
    }

    /// Get holding by ID
    func getHolding(by id: String) -> DepotHolding? {
        holdings.first { $0.id.uuidString == id }
    }

    /// Get order by ID
    func getOrder(by id: String) -> Order? {
        activeOrders.first { $0.id == id }
    }

    /// Get trade by ID
    func getTrade(by id: String) -> Trade? {
        completedTrades.first { $0.id == id }
    }
}
