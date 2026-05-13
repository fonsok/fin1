import Combine
import Foundation

// MARK: - Trading Coordinator Protocol
/// Defines the contract for coordinating trading operations across multiple services
/// Handles complex business logic and cross-service interactions
@MainActor
protocol TradingCoordinatorProtocol: Sendable {
    // MARK: - State Publishers
    var activeOrdersPublisher: AnyPublisher<[Order], Never> { get }
    var completedTradesPublisher: AnyPublisher<[Trade], Never> { get }
    var watchlistPublisher: AnyPublisher<[SearchResult], Never> { get }
    var isLoadingPublisher: AnyPublisher<Bool, Never> { get }
    var errorMessagePublisher: AnyPublisher<String?, Never> { get }

    // MARK: - Trading Operations
    func loadAllTradingData() async throws
    func refreshTradingData() async throws

    // MARK: - Order Management
    func placeBuyOrder(
        symbol: String,
        quantity: Int,
        price: Double,
        optionDirection: String?,
        description: String?,
        orderInstruction: String?,
        limitPrice: Double?,
        strike: Double?,
        subscriptionRatio: Double?,
        denomination: Int?,
        isMirrorPoolOrder: Bool?
    ) async throws -> OrderBuy
    func placeSellOrder(symbol: String, quantity: Int, price: Double) async throws -> OrderSell
    func submitOrder(_ order: OrderSell) async throws
    func cancelOrder(_ orderId: String) async throws
    func updateOrderStatus(_ orderId: String, status: String) async throws

    // MARK: - Trade Management
    func createNewTrade(buyOrder: OrderBuy) async throws -> Trade
    func addSellOrderToTrade(_ tradeId: String, sellOrder: OrderSell) async throws
    func cancelTrade(_ tradeId: String) async throws
    func completeTrade(_ tradeId: String) async throws

    // MARK: - Watchlist Management
    func addToWatchlist(_ searchResult: SearchResult) async throws
    func removeFromWatchlist(_ wkn: String) async throws
    func clearWatchlist() async throws
    func isInWatchlist(_ wkn: String) -> Bool

    // MARK: - Statistics
    func calculateTotalVolume() -> Double
    func calculateDailyPnL() -> Double

    // MARK: - Lifecycle
    func start()
    func stop()
    func reset()
}
