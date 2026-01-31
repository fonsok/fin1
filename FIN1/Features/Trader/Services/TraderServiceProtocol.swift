import Foundation
import Combine

// MARK: - Buy Order Request
struct BuyOrderRequest {
    let symbol: String
    let quantity: Int
    let price: Double
    let optionDirection: String?
    let description: String?
    let orderInstruction: String?
    let limitPrice: Double?
    let strike: Double?
    let subscriptionRatio: Double?
    let denomination: Int?

    init(
        symbol: String,
        quantity: Int,
        price: Double,
        optionDirection: String?,
        description: String?,
        orderInstruction: String?,
        limitPrice: Double?,
        strike: Double?,
        subscriptionRatio: Double? = nil,
        denomination: Int? = nil
    ) {
        self.symbol = symbol
        self.quantity = quantity
        self.price = price
        self.optionDirection = optionDirection
        self.description = description
        self.orderInstruction = orderInstruction
        self.limitPrice = limitPrice
        self.strike = strike
        self.subscriptionRatio = subscriptionRatio
        self.denomination = denomination
    }
}

// MARK: - Trader Service Protocol
/// Defines the contract for trader trading operations and management
/// This is now a facade that coordinates between focused services
protocol TraderServiceProtocol: ObservableObject {
    var activeOrders: [Order] { get }
    var completedTrades: [Trade] { get }
    var orders: [Order] { get }
    var watchlist: [SearchResult] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // Publishers for observation (MVVM-friendly)
    var activeOrdersPublisher: AnyPublisher<[Order], Never> { get }
    var completedTradesPublisher: AnyPublisher<[Trade], Never> { get }

    // MARK: - Trading Data Management
    func loadAllTradingData() async throws
    func refreshTradingData() async throws
    func loadActiveOrders() async throws
    func loadCompletedTrades() async throws
    func loadOrders() async throws

    // MARK: - Trade Management
    func createNewTrade(buyOrder: OrderBuy) async throws -> Trade
    func addSellOrderToTrade(_ tradeId: String, sellOrder: OrderSell) async throws
    func cancelTrade(_ tradeId: String) async throws
    func completeTrade(_ tradeId: String) async throws

    // MARK: - Order Management
    func placeBuyOrder(_ orderRequest: BuyOrderRequest) async throws -> OrderBuy
    func placeSellOrder(symbol: String, quantity: Int, price: Double) async throws -> OrderSell
    func submitOrder(_ order: OrderSell) async throws
    func cancelOrder(_ orderId: String) async throws
    func updateOrderStatus(_ orderId: String, status: String) async throws

    // MARK: - Watchlist Management
    func addToWatchlist(_ searchResult: SearchResult) async throws
    func removeFromWatchlist(_ wkn: String) async throws
    func clearWatchlist() async throws
    func isInWatchlist(_ wkn: String) -> Bool

    // MARK: - Statistics
    func calculateTotalVolume() -> Double
    func calculateDailyPnL() -> Double
}
