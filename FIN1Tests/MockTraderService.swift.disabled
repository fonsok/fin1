import Foundation
import Combine
@testable import FIN1

// MARK: - Mock Trader Service (Simplified)
/// Simplified mock using closure-based behavior instead of multiple configuration properties
class MockTraderService: TraderServiceProtocol {
    @Published var activeOrders: [Order] = []
    @Published var completedTrades: [Trade] = []
    @Published var orders: [Order] = []
    @Published var watchlist: [SearchResult] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    var activeOrdersPublisher: AnyPublisher<[Order], Never> { $activeOrders.eraseToAnyPublisher() }
    var completedTradesPublisher: AnyPublisher<[Trade], Never> { $completedTrades.eraseToAnyPublisher() }

    // MARK: - Behavior Closures (Simplified Approach)
    /// Closure to handle loadAllTradingData - defaults to no-op
    var loadAllTradingDataHandler: (() async throws -> Void)?

    /// Closure to handle createNewTrade - defaults to creating simple trade
    var createNewTradeHandler: ((OrderBuy) async throws -> Trade)?

    /// Closure to handle placeBuyOrder - defaults to creating simple order
    var placeBuyOrderHandler: ((BuyOrderRequest) async throws -> OrderBuy)?

    /// Closure to handle placeSellOrder - defaults to creating simple order
    var placeSellOrderHandler: ((String, Int, Double) async throws -> OrderSell)?

    func loadAllTradingData() async throws {
        if let handler = loadAllTradingDataHandler {
            try await handler()
        }
        // Default: no-op
    }

    func refreshTradingData() async throws {
        // Default: no-op
    }

    func loadActiveOrders() async throws {
        // Default: no-op
    }

    func loadCompletedTrades() async throws {
        // Default: no-op
    }

    func loadOrders() async throws {
        // Default: no-op
    }

    func createNewTrade(buyOrder: OrderBuy) async throws -> Trade {
        if let handler = createNewTradeHandler {
            return try await handler(buyOrder)
        } else {
            // Default: create simple trade
            return Trade(
                id: "1",
                traderId: buyOrder.traderId,
                symbol: buyOrder.symbol,
                description: buyOrder.description,
                buyOrder: buyOrder,
                sellOrder: nil,
                sellOrders: [],
                status: .active,
                createdAt: Date(),
                completedAt: nil,
                updatedAt: Date()
            )
        }
    }

    func addSellOrderToTrade(_ tradeId: String, sellOrder: OrderSell) async throws {
        // Default: no-op
    }

    func cancelTrade(_ tradeId: String) async throws {
        // Default: no-op
    }

    func completeTrade(_ tradeId: String) async throws {
        // Default: no-op
    }

    func placeBuyOrder(_ orderRequest: BuyOrderRequest) async throws -> OrderBuy {
        if let handler = placeBuyOrderHandler {
            return try await handler(orderRequest)
        } else {
            // Default: create simple order
            return OrderBuy(
                id: "1",
                traderId: "1",
                symbol: orderRequest.symbol,
                description: orderRequest.description ?? "Test",
                quantity: Double(orderRequest.quantity),
                price: orderRequest.price,
                totalAmount: Double(orderRequest.quantity) * orderRequest.price,
                status: .submitted,
                createdAt: Date(),
                executedAt: nil,
                confirmedAt: nil,
                updatedAt: Date(),
                optionDirection: orderRequest.optionDirection,
                underlyingAsset: nil,
                wkn: nil,
                category: nil,
                orderInstruction: orderRequest.orderInstruction,
                limitPrice: orderRequest.limitPrice
            )
        }
    }

    func placeSellOrder(symbol: String, quantity: Int, price: Double) async throws -> OrderSell {
        if let handler = placeSellOrderHandler {
            return try await handler(symbol, quantity, price)
        } else {
            // Default: create simple order
            return OrderSell(
                id: "1",
                traderId: "1",
                symbol: symbol,
                description: "Test Sell Order",
                quantity: Double(quantity),
                price: price,
                totalAmount: Double(quantity) * price,
                status: .submitted,
                createdAt: Date(),
                executedAt: nil,
                confirmedAt: nil,
                updatedAt: Date(),
                optionDirection: nil,
                underlyingAsset: nil,
                wkn: nil,
                category: nil,
                orderInstruction: "market",
                limitPrice: nil,
                originalHoldingId: nil
            )
        }
    }

    func submitOrder(_ order: OrderSell) async throws {
        // Default: no-op
    }

    func cancelOrder(_ orderId: String) async throws {
        // Default: no-op
    }

    func updateOrderStatus(_ orderId: String, status: String) async throws {
        // Default: no-op
    }

    func addToWatchlist(_ searchResult: SearchResult) async throws {
        // Default: no-op
    }

    func removeFromWatchlist(_ wkn: String) async throws {
        // Default: no-op
    }

    func clearWatchlist() async throws {
        // Default: no-op
    }

    func isInWatchlist(_ wkn: String) -> Bool {
        return watchlist.contains { $0.wkn == wkn }
    }

    func calculateTotalVolume() -> Double {
        return 10000.0
    }

    func calculateDailyPnL() -> Double {
        return 500.0
    }

    func start() {}
    func stop() {}

    func reset() {
        activeOrders.removeAll()
        completedTrades.removeAll()
        orders.removeAll()
        watchlist.removeAll()
        isLoading = false
        errorMessage = nil
        // Reset all handlers
        loadAllTradingDataHandler = nil
        createNewTradeHandler = nil
        placeBuyOrderHandler = nil
        placeSellOrderHandler = nil
    }
}
