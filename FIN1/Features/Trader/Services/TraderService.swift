import Combine
import Foundation

// MARK: - Notification Names
extension Notification.Name {
    static let sellOrderCompleted = Notification.Name("sellOrderCompleted")
}

// MARK: - Trader Service Implementation
/// Pure facade service that delegates to TradingCoordinator
/// Follows Single Responsibility Principle - only handles interface delegation
/// Uses dependency injection instead of singletons for better testability
@MainActor
final class TraderService: TraderServiceProtocol {

    // MARK: - Published Properties (Facade)
    @Published var activeOrders: [Order] = []
    @Published var completedTrades: [Trade] = []
    @Published var orders: [Order] = []
    @Published var watchlist: [SearchResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Publishers for observation (MVVM-friendly)
    var activeOrdersPublisher: AnyPublisher<[Order], Never> {
        self.$activeOrders.eraseToAnyPublisher()
    }
    var completedTradesPublisher: AnyPublisher<[Trade], Never> {
        self.$completedTrades.eraseToAnyPublisher()
    }

    // MARK: - Coordinator
    private let tradingCoordinator: any TradingCoordinatorProtocol

    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()

    init(tradingCoordinator: any TradingCoordinatorProtocol) {
        self.tradingCoordinator = tradingCoordinator
        self.setupCoordinatorObservers()
    }

    // MARK: - Trading Data Management

    func loadAllTradingData() async throws {
        try await self.tradingCoordinator.loadAllTradingData()
    }

    func refreshTradingData() async throws {
        try await self.tradingCoordinator.refreshTradingData()
    }

    func loadActiveOrders() async throws {
        try await self.tradingCoordinator.loadAllTradingData()
    }

    func loadCompletedTrades() async throws {
        try await self.tradingCoordinator.loadAllTradingData()
    }

    func loadOrders() async throws {
        try await self.tradingCoordinator.loadAllTradingData()
    }

    // MARK: - Trade Management

    func createNewTrade(buyOrder: OrderBuy) async throws -> Trade {
        return try await self.tradingCoordinator.createNewTrade(buyOrder: buyOrder)
    }

    func addSellOrderToTrade(_ tradeId: String, sellOrder: OrderSell) async throws {
        try await self.tradingCoordinator.addSellOrderToTrade(tradeId, sellOrder: sellOrder)
    }

    func cancelTrade(_ tradeId: String) async throws {
        try await self.tradingCoordinator.cancelTrade(tradeId)
    }

    func completeTrade(_ tradeId: String) async throws {
        try await self.tradingCoordinator.completeTrade(tradeId)
    }

    // MARK: - Order Management

    func placeBuyOrder(_ orderRequest: BuyOrderRequest) async throws -> OrderBuy {
        return try await self.tradingCoordinator.placeBuyOrder(
            symbol: orderRequest.symbol,
            quantity: orderRequest.quantity,
            price: orderRequest.price,
            optionDirection: orderRequest.optionDirection,
            description: orderRequest.description,
            orderInstruction: orderRequest.orderInstruction,
            limitPrice: orderRequest.limitPrice,
            strike: orderRequest.strike,
            subscriptionRatio: orderRequest.subscriptionRatio,
            denomination: orderRequest.denomination,
            isMirrorPoolOrder: orderRequest.isMirrorPoolOrder
        )
    }

    func placeSellOrder(symbol: String, quantity: Int, price: Double) async throws -> OrderSell {
        return try await self.tradingCoordinator.placeSellOrder(symbol: symbol, quantity: quantity, price: price)
    }

    func submitOrder(_ order: OrderSell) async throws {
        try await self.tradingCoordinator.submitOrder(order)
    }

    func cancelOrder(_ orderId: String) async throws {
        try await self.tradingCoordinator.cancelOrder(orderId)
    }

    func updateOrderStatus(_ orderId: String, status: String) async throws {
        try await self.tradingCoordinator.updateOrderStatus(orderId, status: status)
    }

    // MARK: - Watchlist Management

    func addToWatchlist(_ searchResult: SearchResult) async throws {
        try await self.tradingCoordinator.addToWatchlist(searchResult)
    }

    func removeFromWatchlist(_ wkn: String) async throws {
        try await self.tradingCoordinator.removeFromWatchlist(wkn)
    }

    func clearWatchlist() async throws {
        try await self.tradingCoordinator.clearWatchlist()
    }

    func isInWatchlist(_ wkn: String) -> Bool {
        return self.tradingCoordinator.isInWatchlist(wkn)
    }

    // MARK: - Statistics

    func calculateTotalVolume() -> Double {
        return self.tradingCoordinator.calculateTotalVolume()
    }

    func calculateDailyPnL() -> Double {
        return self.tradingCoordinator.calculateDailyPnL()
    }

    // MARK: - Private Methods

    private func setupCoordinatorObservers() {
        // Observe coordinator state changes and forward to facade properties
        self.tradingCoordinator.activeOrdersPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.activeOrders, on: self)
            .store(in: &self.cancellables)

        self.tradingCoordinator.completedTradesPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.completedTrades, on: self)
            .store(in: &self.cancellables)

        self.tradingCoordinator.watchlistPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.watchlist, on: self)
            .store(in: &self.cancellables)

        self.tradingCoordinator.isLoadingPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &self.cancellables)

        self.tradingCoordinator.errorMessagePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &self.cancellables)
    }
}

// MARK: - ServiceLifecycle
/// `ServiceLifecycle` is not MainActor-isolated; these hop to the main actor without making the conformance cross isolation.
extension TraderService: ServiceLifecycle {
    nonisolated func start() {
        Task { @MainActor [weak self] in
            self?.tradingCoordinator.start()
        }
    }

    nonisolated func stop() {
        Task { @MainActor [weak self] in
            self?.tradingCoordinator.stop()
        }
    }

    nonisolated func reset() {
        Task { @MainActor [weak self] in
            self?.tradingCoordinator.reset()
        }
    }
}
