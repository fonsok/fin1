import Foundation

// MARK: - Order API Service Protocol

/// Protocol for syncing orders to Parse Server backend
protocol OrderAPIServiceProtocol {
    /// Saves a buy order to the Parse Server
    func saveBuyOrder(_ order: OrderBuy) async throws -> OrderBuy

    /// Saves a sell order to the Parse Server
    func saveSellOrder(_ order: OrderSell) async throws -> OrderSell

    /// Updates an existing order on the Parse Server
    func updateOrder(_ order: Order) async throws -> Order

    /// Fetches all orders for a trader
    func fetchOrders(for traderId: String) async throws -> [Order]

    /// Fetches active orders for a trader
    func fetchActiveOrders(for traderId: String) async throws -> [Order]

    /// Cancels an order on the Parse Server
    func cancelOrder(_ orderId: String) async throws
}

// MARK: - Parse Order Input

/// Input struct for creating/updating orders on Parse Server
private struct ParseOrderInput: Codable {
    let traderId: String
    let symbol: String
    let description: String
    let type: String
    let quantity: Double
    let price: Double
    let totalAmount: Double
    let status: String
    let executedAt: String?
    let confirmedAt: String?
    let optionDirection: String?
    let underlyingAsset: String?
    let wkn: String?
    let category: String?
    let strike: Double?
    let orderInstruction: String?
    let limitPrice: Double?
    let subscriptionRatio: Double?
    let denomination: Int?
    let originalHoldingId: String?

    static func from(buyOrder: OrderBuy) -> ParseOrderInput {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return ParseOrderInput(
            traderId: buyOrder.traderId,
            symbol: buyOrder.symbol,
            description: buyOrder.description,
            type: "buy",
            quantity: buyOrder.quantity,
            price: buyOrder.price,
            totalAmount: buyOrder.totalAmount,
            status: buyOrder.status.rawValue,
            executedAt: buyOrder.executedAt.map { dateFormatter.string(from: $0) },
            confirmedAt: buyOrder.confirmedAt.map { dateFormatter.string(from: $0) },
            optionDirection: buyOrder.optionDirection,
            underlyingAsset: buyOrder.underlyingAsset,
            wkn: buyOrder.wkn,
            category: buyOrder.category,
            strike: buyOrder.strike,
            orderInstruction: buyOrder.orderInstruction,
            limitPrice: buyOrder.limitPrice,
            subscriptionRatio: buyOrder.subscriptionRatio,
            denomination: buyOrder.denomination,
            originalHoldingId: nil
        )
    }

    static func from(sellOrder: OrderSell) -> ParseOrderInput {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return ParseOrderInput(
            traderId: sellOrder.traderId,
            symbol: sellOrder.symbol,
            description: sellOrder.description,
            type: "sell",
            quantity: sellOrder.quantity,
            price: sellOrder.price,
            totalAmount: sellOrder.totalAmount,
            status: sellOrder.status.rawValue,
            executedAt: sellOrder.executedAt.map { dateFormatter.string(from: $0) },
            confirmedAt: sellOrder.confirmedAt.map { dateFormatter.string(from: $0) },
            optionDirection: sellOrder.optionDirection,
            underlyingAsset: sellOrder.underlyingAsset,
            wkn: sellOrder.wkn,
            category: sellOrder.category,
            strike: sellOrder.strike,
            orderInstruction: sellOrder.orderInstruction,
            limitPrice: sellOrder.limitPrice,
            subscriptionRatio: nil,
            denomination: nil,
            originalHoldingId: sellOrder.originalHoldingId
        )
    }

    static func from(order: Order) -> ParseOrderInput {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return ParseOrderInput(
            traderId: order.traderId,
            symbol: order.symbol,
            description: order.description,
            type: order.type.rawValue,
            quantity: order.quantity,
            price: order.price,
            totalAmount: order.totalAmount,
            status: order.status,
            executedAt: order.executedAt.map { dateFormatter.string(from: $0) },
            confirmedAt: order.confirmedAt.map { dateFormatter.string(from: $0) },
            optionDirection: order.optionDirection,
            underlyingAsset: order.underlyingAsset,
            wkn: order.wkn,
            category: order.category,
            strike: order.strike,
            orderInstruction: order.orderInstruction,
            limitPrice: order.limitPrice,
            subscriptionRatio: order.subscriptionRatio,
            denomination: order.denomination,
            originalHoldingId: order.originalHoldingId
        )
    }
}

// MARK: - Parse Order Response

/// Response struct for Parse Server order operations (internal for unit tests with `MockParseAPIClient`.)
struct ParseOrderResponse: Codable, Sendable {
    let objectId: String
    let traderId: String
    let symbol: String
    let description: String
    let type: String
    let quantity: Double
    let price: Double
    let totalAmount: Double
    let status: String
    let createdAt: String
    let updatedAt: String
    let executedAt: String?
    let confirmedAt: String?
    let optionDirection: String?
    let underlyingAsset: String?
    let wkn: String?
    let category: String?
    let strike: Double?
    let orderInstruction: String?
    let limitPrice: Double?
    let subscriptionRatio: Double?
    let denomination: Int?
    let originalHoldingId: String?

    func toOrderBuy() -> OrderBuy {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let createdDate = dateFormatter.date(from: self.createdAt) ?? Date()
        let updatedDate = dateFormatter.date(from: self.updatedAt) ?? Date()
        let executedDate = self.executedAt.flatMap { dateFormatter.date(from: $0) }
        let confirmedDate = self.confirmedAt.flatMap { dateFormatter.date(from: $0) }
        let orderStatus = OrderBuyStatus(rawValue: status) ?? .submitted

        return OrderBuy(
            id: self.objectId,
            traderId: self.traderId,
            symbol: self.symbol,
            description: self.description,
            quantity: self.quantity,
            price: self.price,
            totalAmount: self.totalAmount,
            status: orderStatus,
            createdAt: createdDate,
            executedAt: executedDate,
            confirmedAt: confirmedDate,
            updatedAt: updatedDate,
            optionDirection: self.optionDirection,
            underlyingAsset: self.underlyingAsset,
            wkn: self.wkn,
            category: self.category,
            strike: self.strike,
            orderInstruction: self.orderInstruction,
            limitPrice: self.limitPrice,
            subscriptionRatio: self.subscriptionRatio,
            denomination: self.denomination
        )
    }

    func toOrderSell() -> OrderSell {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let createdDate = dateFormatter.date(from: self.createdAt) ?? Date()
        let updatedDate = dateFormatter.date(from: self.updatedAt) ?? Date()
        let executedDate = self.executedAt.flatMap { dateFormatter.date(from: $0) }
        let confirmedDate = self.confirmedAt.flatMap { dateFormatter.date(from: $0) }
        let orderStatus = OrderSellStatus(rawValue: status) ?? .submitted

        return OrderSell(
            id: self.objectId,
            traderId: self.traderId,
            symbol: self.symbol,
            description: self.description,
            quantity: self.quantity,
            price: self.price,
            totalAmount: self.totalAmount,
            status: orderStatus,
            createdAt: createdDate,
            executedAt: executedDate,
            confirmedAt: confirmedDate,
            updatedAt: updatedDate,
            optionDirection: self.optionDirection,
            underlyingAsset: self.underlyingAsset,
            wkn: self.wkn,
            category: self.category,
            strike: self.strike,
            orderInstruction: self.orderInstruction,
            limitPrice: self.limitPrice,
            originalHoldingId: self.originalHoldingId
        )
    }

    func toOrder() -> Order {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let createdDate = dateFormatter.date(from: self.createdAt) ?? Date()
        let updatedDate = dateFormatter.date(from: self.updatedAt) ?? Date()
        let executedDate = self.executedAt.flatMap { dateFormatter.date(from: $0) }
        let confirmedDate = self.confirmedAt.flatMap { dateFormatter.date(from: $0) }
        let orderType: OrderType = self.type == "buy" ? .buy : .sell

        return Order(
            id: self.objectId,
            traderId: self.traderId,
            symbol: self.symbol,
            description: self.description,
            type: orderType,
            quantity: self.quantity,
            price: self.price,
            totalAmount: self.totalAmount,
            createdAt: createdDate,
            executedAt: executedDate,
            confirmedAt: confirmedDate,
            updatedAt: updatedDate,
            optionDirection: self.optionDirection,
            underlyingAsset: self.underlyingAsset,
            wkn: self.wkn,
            category: self.category,
            strike: self.strike,
            orderInstruction: self.orderInstruction,
            limitPrice: self.limitPrice,
            subscriptionRatio: self.subscriptionRatio,
            denomination: self.denomination,
            originalHoldingId: self.originalHoldingId,
            status: self.status
        )
    }
}

// MARK: - Order API Service Implementation

/// Service for syncing orders with Parse Server backend
final class OrderAPIService: OrderAPIServiceProtocol {
    private let apiClient: ParseAPIClientProtocol
    private let className = "Order"

    init(apiClient: ParseAPIClientProtocol) {
        self.apiClient = apiClient
    }

    // MARK: - Save Buy Order

    func saveBuyOrder(_ order: OrderBuy) async throws -> OrderBuy {
        print("📡 OrderAPIService: Saving buy order to Parse Server")

        let input = ParseOrderInput.from(buyOrder: order)
        let response = try await apiClient.createObject(
            className: self.className,
            object: input
        )

        print("✅ OrderAPIService: Buy order saved with objectId: \(response.objectId)")

        // Return order with Parse objectId
        return OrderBuy(
            id: response.objectId,
            traderId: order.traderId,
            symbol: order.symbol,
            description: order.description,
            quantity: order.quantity,
            price: order.price,
            totalAmount: order.totalAmount,
            status: order.status,
            createdAt: order.createdAt,
            executedAt: order.executedAt,
            confirmedAt: order.confirmedAt,
            updatedAt: order.updatedAt,
            optionDirection: order.optionDirection,
            underlyingAsset: order.underlyingAsset,
            wkn: order.wkn,
            category: order.category,
            strike: order.strike,
            orderInstruction: order.orderInstruction,
            limitPrice: order.limitPrice,
            subscriptionRatio: order.subscriptionRatio,
            denomination: order.denomination
        )
    }

    // MARK: - Save Sell Order

    func saveSellOrder(_ order: OrderSell) async throws -> OrderSell {
        print("📡 OrderAPIService: Saving sell order to Parse Server")

        let input = ParseOrderInput.from(sellOrder: order)
        let response = try await apiClient.createObject(
            className: self.className,
            object: input
        )

        print("✅ OrderAPIService: Sell order saved with objectId: \(response.objectId)")

        // Return order with Parse objectId
        return OrderSell(
            id: response.objectId,
            traderId: order.traderId,
            symbol: order.symbol,
            description: order.description,
            quantity: order.quantity,
            price: order.price,
            totalAmount: order.totalAmount,
            status: order.status,
            createdAt: order.createdAt,
            executedAt: order.executedAt,
            confirmedAt: order.confirmedAt,
            updatedAt: order.updatedAt,
            optionDirection: order.optionDirection,
            underlyingAsset: order.underlyingAsset,
            wkn: order.wkn,
            category: order.category,
            strike: order.strike,
            orderInstruction: order.orderInstruction,
            limitPrice: order.limitPrice,
            originalHoldingId: order.originalHoldingId
        )
    }

    // MARK: - Update Order

    func updateOrder(_ order: Order) async throws -> Order {
        print("📡 OrderAPIService: Updating order on Parse Server")

        let input = ParseOrderInput.from(order: order)
        let response = try await apiClient.updateObject(
            className: self.className,
            objectId: order.id,
            object: input
        )

        print("✅ OrderAPIService: Order updated: \(response.objectId)")

        // Return updated order
        return order
    }

    // MARK: - Fetch Orders

    func fetchOrders(for traderId: String) async throws -> [Order] {
        print("📡 OrderAPIService: Fetching orders for trader: \(traderId)")

        let responses: [ParseOrderResponse] = try await apiClient.fetchObjects(
            className: self.className,
            query: ["traderId": traderId],
            include: nil,
            orderBy: "-createdAt",
            limit: 100
        )

        print("✅ OrderAPIService: Fetched \(responses.count) orders")
        return responses.map { $0.toOrder() }
    }

    // MARK: - Fetch Active Orders

    func fetchActiveOrders(for traderId: String) async throws -> [Order] {
        // Fetch orders that are not completed or cancelled
        let allOrders = try await fetchOrders(for: traderId)

        return allOrders.filter { order in
            let status = order.status.lowercased()
            return status != "completed" && status != "cancelled"
        }
    }

    // MARK: - Cancel Order

    func cancelOrder(_ orderId: String) async throws {
        print("📡 OrderAPIService: Cancelling order: \(orderId)")

        // Update order status to cancelled
        struct CancelInput: Codable {
            let status: String
        }

        _ = try await self.apiClient.updateObject(
            className: self.className,
            objectId: orderId,
            object: CancelInput(status: "cancelled")
        )

        print("✅ OrderAPIService: Order cancelled")
    }
}
