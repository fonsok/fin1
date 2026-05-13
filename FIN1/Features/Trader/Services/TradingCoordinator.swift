import Combine
import Foundation

// MARK: - Trading Coordinator Implementation
/// Lightweight orchestrator that coordinates between focused trading services
/// Delegates to specialized coordinators and state managers
@MainActor
final class TradingCoordinator: TradingCoordinatorProtocol {

    // MARK: - Publishers (Delegated to State Store)
    var activeOrdersPublisher: AnyPublisher<[Order], Never> {
        self.tradingStateStore.activeOrdersPublisher
    }

    var completedTradesPublisher: AnyPublisher<[Trade], Never> {
        self.tradingStateStore.completedTradesPublisher
    }

    var watchlistPublisher: AnyPublisher<[SearchResult], Never> {
        self.tradingStateStore.watchlistPublisher
    }

    var isLoadingPublisher: AnyPublisher<Bool, Never> {
        self.tradingStateStore.isLoadingPublisher
    }

    var errorMessagePublisher: AnyPublisher<String?, Never> {
        self.tradingStateStore.errorMessagePublisher
    }

    // MARK: - Focused Coordinators
    private let tradingStateStore: any TradingStateLifecycleProtocol
    private let orderLifecycleCoordinator: any OrderLifecycleCoordinatorProtocol
    private let tradeLifecycleCoordinator: any TradeLifecycleCoordinatorProtocol
    private let securitiesWatchlistService: any SecuritiesWatchlistServiceProtocol
    private let tradingStatisticsService: any TradingStatisticsServiceProtocol

    // MARK: - Initialization
    init(
        tradingStateStore: any TradingStateLifecycleProtocol,
        orderLifecycleCoordinator: any OrderLifecycleCoordinatorProtocol,
        tradeLifecycleCoordinator: any TradeLifecycleCoordinatorProtocol,
        securitiesWatchlistService: any SecuritiesWatchlistServiceProtocol,
        tradingStatisticsService: any TradingStatisticsServiceProtocol
    ) {
        self.tradingStateStore = tradingStateStore
        self.orderLifecycleCoordinator = orderLifecycleCoordinator
        self.tradeLifecycleCoordinator = tradeLifecycleCoordinator
        self.securitiesWatchlistService = securitiesWatchlistService
        self.tradingStatisticsService = tradingStatisticsService
    }

    // MARK: - Trading Operations

    func loadAllTradingData() async throws {
        try await self.tradingStateStore.loadAllTradingData()
    }

    func refreshTradingData() async throws {
        try await self.tradingStateStore.refreshTradingData()
    }

    // MARK: - Order Management

    func placeBuyOrder(
        symbol: String,
        quantity: Int,
        price: Double,
        optionDirection: String? = nil,
        description: String? = nil,
        orderInstruction: String? = nil,
        limitPrice: Double? = nil,
        strike: Double? = nil,
        subscriptionRatio: Double? = nil,
        denomination: Int? = nil,
        isMirrorPoolOrder: Bool? = nil
    ) async throws -> OrderBuy {
        let parameters = BuyOrderParameters(
            symbol: symbol,
            quantity: quantity,
            price: price,
            optionDirection: optionDirection,
            description: description,
            orderInstruction: orderInstruction,
            limitPrice: limitPrice,
            strike: strike,
            subscriptionRatio: subscriptionRatio,
            denomination: denomination,
            isMirrorPoolOrder: isMirrorPoolOrder
        )
        return try await self.orderLifecycleCoordinator.placeBuyOrder(parameters: parameters)
    }

    func placeSellOrder(symbol: String, quantity: Int, price: Double) async throws -> OrderSell {
        return try await self.orderLifecycleCoordinator.placeSellOrder(symbol: symbol, quantity: quantity, price: price)
    }

    func submitOrder(_ order: OrderSell) async throws {
        try await self.orderLifecycleCoordinator.submitOrder(order)
    }

    func cancelOrder(_ orderId: String) async throws {
        try await self.orderLifecycleCoordinator.cancelOrder(orderId)
    }

    func updateOrderStatus(_ orderId: String, status: String) async throws {
        try await self.orderLifecycleCoordinator.updateOrderStatus(orderId, status: status)
    }

    // MARK: - Trade Management

    func createNewTrade(buyOrder: OrderBuy) async throws -> Trade {
        return try await self.tradeLifecycleCoordinator.createNewTrade(buyOrder: buyOrder)
    }

    func addSellOrderToTrade(_ tradeId: String, sellOrder: OrderSell) async throws {
        try await self.tradeLifecycleCoordinator.addSellOrderToTrade(tradeId, sellOrder: sellOrder)
    }

    func cancelTrade(_ tradeId: String) async throws {
        try await self.tradeLifecycleCoordinator.cancelTrade(tradeId)
    }

    func completeTrade(_ tradeId: String) async throws {
        try await self.tradeLifecycleCoordinator.completeTrade(tradeId)
    }

    // MARK: - Watchlist Management

    func addToWatchlist(_ searchResult: SearchResult) async throws {
        try await self.securitiesWatchlistService.addToWatchlist(searchResult)
    }

    func removeFromWatchlist(_ wkn: String) async throws {
        try await self.securitiesWatchlistService.removeFromWatchlist(wkn)
    }

    func clearWatchlist() async throws {
        try await self.securitiesWatchlistService.clearWatchlist()
    }

    func isInWatchlist(_ wkn: String) -> Bool {
        return self.securitiesWatchlistService.isInWatchlist(wkn)
    }

    // MARK: - Statistics

    func calculateTotalVolume() -> Double {
        // Note: This would need access to current state from TradingStateStore
        // For now, we'll delegate to the statistics service with empty arrays
        // In a real implementation, we'd need to get current state from the state store
        return self.tradingStatisticsService.calculateTotalVolume(activeOrders: [], completedTrades: [])
    }

    func calculateDailyPnL() -> Double {
        // Note: This would need access to current state from TradingStateStore
        // For now, we'll delegate to the statistics service with empty arrays
        return self.tradingStatisticsService.calculateDailyPnL(completedTrades: [])
    }

    // MARK: - Lifecycle

    func start() {
        self.tradingStateStore.start()
    }

    func stop() {
        self.tradingStateStore.stop()
    }

    func reset() {
        self.tradingStateStore.reset()
    }
}
