import Foundation
import Combine

// MARK: - Notification Names
extension Notification.Name {
    static let sellOrderCompleted = Notification.Name("sellOrderCompleted")
}

// MARK: - Trader Service Implementation
/// Pure facade service that delegates to TradingCoordinator
/// Follows Single Responsibility Principle - only handles interface delegation
/// Uses dependency injection instead of singletons for better testability
final class TraderService: TraderServiceProtocol, ServiceLifecycle {

    // MARK: - Published Properties (Facade)
    @Published var activeOrders: [Order] = []
    @Published var completedTrades: [Trade] = []
    @Published var orders: [Order] = []
    @Published var watchlist: [SearchResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Publishers for observation (MVVM-friendly)
    var activeOrdersPublisher: AnyPublisher<[Order], Never> {
        $activeOrders.eraseToAnyPublisher()
    }
    var completedTradesPublisher: AnyPublisher<[Trade], Never> {
        $completedTrades.eraseToAnyPublisher()
    }

    // MARK: - Coordinator
    private let tradingCoordinator: any TradingCoordinatorProtocol

    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()

    init(tradingCoordinator: any TradingCoordinatorProtocol) {
        self.tradingCoordinator = tradingCoordinator
        setupCoordinatorObservers()
    }

    // MARK: - ServiceLifecycle
    func start() {
        tradingCoordinator.start()
    }

    func stop() {
        tradingCoordinator.stop()
    }

    func reset() {
        tradingCoordinator.reset()
    }

    // MARK: - Trading Data Management

    func loadAllTradingData() async throws {
        try await tradingCoordinator.loadAllTradingData()
    }

    func refreshTradingData() async throws {
        try await tradingCoordinator.refreshTradingData()
    }

    func loadActiveOrders() async throws {
        try await tradingCoordinator.loadAllTradingData()
    }

    func loadCompletedTrades() async throws {
        try await tradingCoordinator.loadAllTradingData()
    }

    func loadOrders() async throws {
        try await tradingCoordinator.loadAllTradingData()
    }

    // MARK: - Trade Management

    func createNewTrade(buyOrder: OrderBuy) async throws -> Trade {
        return try await tradingCoordinator.createNewTrade(buyOrder: buyOrder)
    }

    func addSellOrderToTrade(_ tradeId: String, sellOrder: OrderSell) async throws {
        try await tradingCoordinator.addSellOrderToTrade(tradeId, sellOrder: sellOrder)
    }

    func cancelTrade(_ tradeId: String) async throws {
        try await tradingCoordinator.cancelTrade(tradeId)
    }

    func completeTrade(_ tradeId: String) async throws {
        try await tradingCoordinator.completeTrade(tradeId)
    }

    // MARK: - Order Management

    func placeBuyOrder(_ orderRequest: BuyOrderRequest) async throws -> OrderBuy {
        return try await tradingCoordinator.placeBuyOrder(
            symbol: orderRequest.symbol,
            quantity: orderRequest.quantity,
            price: orderRequest.price,
            optionDirection: orderRequest.optionDirection,
            description: orderRequest.description,
            orderInstruction: orderRequest.orderInstruction,
            limitPrice: orderRequest.limitPrice,
            strike: orderRequest.strike,
            subscriptionRatio: orderRequest.subscriptionRatio,
            denomination: orderRequest.denomination
        )
    }

    func placeSellOrder(symbol: String, quantity: Int, price: Double) async throws -> OrderSell {
        return try await tradingCoordinator.placeSellOrder(symbol: symbol, quantity: quantity, price: price)
    }

    func submitOrder(_ order: OrderSell) async throws {
        try await tradingCoordinator.submitOrder(order)
    }

    func cancelOrder(_ orderId: String) async throws {
        try await tradingCoordinator.cancelOrder(orderId)
    }

    func updateOrderStatus(_ orderId: String, status: String) async throws {
        try await tradingCoordinator.updateOrderStatus(orderId, status: status)
    }

    // MARK: - Watchlist Management

    func addToWatchlist(_ searchResult: SearchResult) async throws {
        try await tradingCoordinator.addToWatchlist(searchResult)
    }

    func removeFromWatchlist(_ wkn: String) async throws {
        try await tradingCoordinator.removeFromWatchlist(wkn)
    }

    func clearWatchlist() async throws {
        try await tradingCoordinator.clearWatchlist()
    }

    func isInWatchlist(_ wkn: String) -> Bool {
        return tradingCoordinator.isInWatchlist(wkn)
    }

    // MARK: - Statistics

    func calculateTotalVolume() -> Double {
        return tradingCoordinator.calculateTotalVolume()
    }

    func calculateDailyPnL() -> Double {
        return tradingCoordinator.calculateDailyPnL()
    }

    // MARK: - Private Methods

    private func setupCoordinatorObservers() {
        // Observe coordinator state changes and forward to facade properties
        tradingCoordinator.activeOrdersPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.activeOrders, on: self)
            .store(in: &cancellables)

        tradingCoordinator.completedTradesPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.completedTrades, on: self)
            .store(in: &cancellables)

        tradingCoordinator.watchlistPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.watchlist, on: self)
            .store(in: &cancellables)

        tradingCoordinator.isLoadingPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)

        tradingCoordinator.errorMessagePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
    }
}
