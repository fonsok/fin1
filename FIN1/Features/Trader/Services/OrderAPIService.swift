import Foundation

// MARK: - Order API Service Protocol

/// Protocol for syncing orders to Parse Server backend
protocol OrderAPIServiceProtocol {
    /// Saves a buy order to the Parse Server
    func saveBuyOrder(_ order: OrderBuy) async throws -> OrderBuy

    /// Saves a sell order to the Parse Server
    func saveSellOrder(_ order: OrderSell, tradeId: String?) async throws -> OrderSell

    /// Updates an existing order on the Parse Server
    func updateOrder(_ order: Order, tradeId: String?) async throws -> Order

    /// Fetches all orders for a trader
    func fetchOrders(for traderId: String) async throws -> [Order]

    /// Fetches active orders for a trader
    func fetchActiveOrders(for traderId: String) async throws -> [Order]

    /// Cancels an order on the Parse Server (paired legs cancelled together when applicable).
    func cancelOrder(_ orderId: String) async throws

    /// Server-side settlement for a paired buy after UI reaches execution step.
    func finalizePairedBuyExecution(pairExecutionId: String) async throws

    /// Finalize paired buy (+ optional postDisplayStatus: confirmed|completed) in one server round-trip.
    func commitPairedBuyExecution(pairExecutionId: String, postDisplayStatus: String?) async throws

    /// Advances all legs of a paired buy to the same pre-settlement status (submitted → suspended → confirmed → completed).
    func advancePairedOrderStatus(pairExecutionId: String, status: String) async throws
}

// MARK: - Parse Order Input

/// Input struct for creating/updating orders on Parse Server (matches Order beforeSave schema).
private struct ParseOrderInput: Codable {
    let traderId: String
    let symbol: String
    let description: String?
    let side: String
    let orderType: String
    let quantity: Double
    let price: Double
    let grossAmount: Double?
    let totalAmount: Double?
    let status: String?
    let executedAt: String?
    let confirmedAt: String?
    let executedQuantity: Double?
    let tradeId: String?
    let optionDirection: String?
    let underlyingAsset: String?
    let wkn: String?
    let category: String?
    let strike: Double?
    let limitPrice: Double?
    let subscriptionRatio: Double?
    let denomination: Int?
    let originalHoldingId: String?
    let clientQuotedAt: String?

    private nonisolated(unsafe) static let iso8601NowFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func resolveOrderType(from instruction: String?, limitPrice: Double?) -> String {
        switch instruction?.lowercased() {
        case "limit":
            return "limit"
        case "stop":
            return "stop"
        case "stop_limit", "stop-limit":
            return "stop_limit"
        default:
            return limitPrice != nil ? "limit" : "market"
        }
    }

    private static func grossAmount(for quantity: Double, price: Double, totalAmount: Double) -> Double {
        if totalAmount > 0, quantity > 0, price > 0, abs(totalAmount - quantity * price) < 0.01 {
            return totalAmount
        }
        return quantity * price
    }

    static func from(buyOrder: OrderBuy) -> ParseOrderInput {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let orderType = self.resolveOrderType(from: buyOrder.orderInstruction, limitPrice: buyOrder.limitPrice)
        let gross = self.grossAmount(for: buyOrder.quantity, price: buyOrder.price, totalAmount: buyOrder.totalAmount)

        return ParseOrderInput(
            traderId: buyOrder.traderId,
            symbol: buyOrder.symbol,
            description: buyOrder.description,
            side: "buy",
            orderType: orderType,
            quantity: buyOrder.quantity,
            price: buyOrder.price,
            grossAmount: gross,
            totalAmount: buyOrder.totalAmount,
            status: buyOrder.status.rawValue,
            executedAt: buyOrder.executedAt.map { dateFormatter.string(from: $0) },
            confirmedAt: buyOrder.confirmedAt.map { dateFormatter.string(from: $0) },
            executedQuantity: nil,
            tradeId: nil,
            optionDirection: buyOrder.optionDirection,
            underlyingAsset: buyOrder.underlyingAsset,
            wkn: buyOrder.wkn,
            category: buyOrder.category,
            strike: buyOrder.strike,
            limitPrice: buyOrder.limitPrice,
            subscriptionRatio: buyOrder.subscriptionRatio,
            denomination: buyOrder.denomination,
            originalHoldingId: nil,
            clientQuotedAt: Self.iso8601NowFormatter.string(from: Date())
        )
    }

    static func from(sellOrder: OrderSell, tradeId: String?) -> ParseOrderInput {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let orderType = self.resolveOrderType(from: sellOrder.orderInstruction, limitPrice: sellOrder.limitPrice)
        let gross = self.grossAmount(for: sellOrder.quantity, price: sellOrder.price, totalAmount: sellOrder.totalAmount)
        let executedQty = sellOrder.status == .executed || sellOrder.status == .confirmed
            ? sellOrder.quantity
            : nil

        return ParseOrderInput(
            traderId: sellOrder.traderId,
            symbol: sellOrder.symbol,
            description: sellOrder.description,
            side: "sell",
            orderType: orderType,
            quantity: sellOrder.quantity,
            price: sellOrder.price,
            grossAmount: gross,
            totalAmount: sellOrder.totalAmount,
            status: sellOrder.status.rawValue,
            executedAt: sellOrder.executedAt.map { dateFormatter.string(from: $0) },
            confirmedAt: sellOrder.confirmedAt.map { dateFormatter.string(from: $0) },
            executedQuantity: executedQty,
            tradeId: tradeId,
            optionDirection: sellOrder.optionDirection,
            underlyingAsset: sellOrder.underlyingAsset,
            wkn: sellOrder.wkn ?? sellOrder.symbol,
            category: sellOrder.category,
            strike: sellOrder.strike,
            limitPrice: sellOrder.limitPrice,
            subscriptionRatio: nil,
            denomination: nil,
            originalHoldingId: sellOrder.originalHoldingId,
            clientQuotedAt: Self.iso8601NowFormatter.string(from: Date())
        )
    }

    static func from(order: Order, tradeId: String? = nil) -> ParseOrderInput {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let orderType = self.resolveOrderType(from: order.orderInstruction, limitPrice: order.limitPrice)
        let gross = self.grossAmount(for: order.quantity, price: order.price, totalAmount: order.totalAmount)
        let executedQty = ["executed", "confirmed", "completed"].contains(order.status.lowercased())
            ? order.quantity
            : nil

        return ParseOrderInput(
            traderId: order.traderId,
            symbol: order.symbol,
            description: order.description,
            side: order.type == .buy ? "buy" : "sell",
            orderType: orderType,
            quantity: order.quantity,
            price: order.price,
            grossAmount: gross,
            totalAmount: order.totalAmount,
            status: order.status,
            executedAt: order.executedAt.map { dateFormatter.string(from: $0) },
            confirmedAt: order.confirmedAt.map { dateFormatter.string(from: $0) },
            executedQuantity: executedQty,
            tradeId: tradeId,
            optionDirection: order.optionDirection,
            underlyingAsset: order.underlyingAsset,
            wkn: order.wkn ?? order.symbol,
            category: order.category,
            strike: order.strike,
            limitPrice: order.limitPrice,
            subscriptionRatio: order.subscriptionRatio,
            denomination: order.denomination,
            originalHoldingId: order.originalHoldingId,
            clientQuotedAt: order.type == .sell ? Self.iso8601NowFormatter.string(from: Date()) : nil
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
    let type: String?
    let side: String?
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
    let tradeId: String?
    let isMirrorPoolOrder: Bool?
    let legType: String?
    let pairExecutionId: String?

    enum CodingKeys: String, CodingKey {
        case objectId, traderId, symbol, description, type, side, quantity, price, totalAmount, status
        case createdAt, updatedAt, executedAt, confirmedAt
        case optionDirection, underlyingAsset, wkn, category, strike, orderInstruction, limitPrice
        case subscriptionRatio, denomination, originalHoldingId, tradeId
        case isMirrorPoolOrder, legType, pairExecutionId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.objectId = try container.decode(String.self, forKey: .objectId)
        self.traderId = try container.decodeIfPresent(String.self, forKey: .traderId) ?? ""
        self.symbol = try container.decodeIfPresent(String.self, forKey: .symbol) ?? ""
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? self.symbol
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.side = try container.decodeIfPresent(String.self, forKey: .side)
        self.quantity = try container.decodeIfPresent(Double.self, forKey: .quantity) ?? 0
        self.price = try container.decodeIfPresent(Double.self, forKey: .price) ?? 0
        self.totalAmount = try container.decodeIfPresent(Double.self, forKey: .totalAmount) ?? 0
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? "pending"
        self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ISO8601DateFormatter().string(from: Date())
        self.updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? self.createdAt
        self.executedAt = try container.decodeIfPresent(String.self, forKey: .executedAt)
        self.confirmedAt = try container.decodeIfPresent(String.self, forKey: .confirmedAt)
        self.optionDirection = try container.decodeIfPresent(String.self, forKey: .optionDirection)
        self.underlyingAsset = try container.decodeIfPresent(String.self, forKey: .underlyingAsset)
        self.wkn = try container.decodeIfPresent(String.self, forKey: .wkn)
        self.category = try container.decodeIfPresent(String.self, forKey: .category)
        self.strike = try container.decodeIfPresent(Double.self, forKey: .strike)
        self.orderInstruction = try container.decodeIfPresent(String.self, forKey: .orderInstruction)
        self.limitPrice = try container.decodeIfPresent(Double.self, forKey: .limitPrice)
        self.subscriptionRatio = try container.decodeIfPresent(Double.self, forKey: .subscriptionRatio)
        self.denomination = try container.decodeIfPresent(Int.self, forKey: .denomination)
        self.originalHoldingId = try container.decodeIfPresent(String.self, forKey: .originalHoldingId)
        self.tradeId = try container.decodeIfPresent(String.self, forKey: .tradeId)
        self.isMirrorPoolOrder = try container.decodeIfPresent(Bool.self, forKey: .isMirrorPoolOrder)
        self.legType = try container.decodeIfPresent(String.self, forKey: .legType)
        self.pairExecutionId = try container.decodeIfPresent(String.self, forKey: .pairExecutionId)
    }

    private var resolvedSide: String {
        let raw = (side ?? self.type ?? "buy").lowercased()
        return raw
    }

    init(
        objectId: String,
        traderId: String,
        symbol: String,
        description: String,
        type: String?,
        side: String? = nil,
        quantity: Double,
        price: Double,
        totalAmount: Double,
        status: String,
        createdAt: String,
        updatedAt: String,
        executedAt: String?,
        confirmedAt: String?,
        optionDirection: String?,
        underlyingAsset: String?,
        wkn: String?,
        category: String?,
        strike: Double?,
        orderInstruction: String?,
        limitPrice: Double?,
        subscriptionRatio: Double?,
        denomination: Int?,
        originalHoldingId: String?,
        tradeId: String? = nil,
        isMirrorPoolOrder: Bool? = nil,
        legType: String? = nil,
        pairExecutionId: String? = nil
    ) {
        self.objectId = objectId
        self.traderId = traderId
        self.symbol = symbol
        self.description = description
        self.type = type
        self.side = side ?? type
        self.quantity = quantity
        self.price = price
        self.totalAmount = totalAmount
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.executedAt = executedAt
        self.confirmedAt = confirmedAt
        self.optionDirection = optionDirection
        self.underlyingAsset = underlyingAsset
        self.wkn = wkn
        self.category = category
        self.strike = strike
        self.orderInstruction = orderInstruction
        self.limitPrice = limitPrice
        self.subscriptionRatio = subscriptionRatio
        self.denomination = denomination
        self.originalHoldingId = originalHoldingId
        self.tradeId = tradeId
        self.isMirrorPoolOrder = isMirrorPoolOrder
        self.legType = legType
        self.pairExecutionId = pairExecutionId
    }

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
        let orderType: OrderType = self.resolvedSide == "buy" ? .buy : .sell

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
            isMirrorPoolOrder: self.isMirrorPoolOrder == true
                || self.legType?.uppercased() == "MIRROR_POOL",
            originalHoldingId: self.originalHoldingId,
            pairExecutionId: self.pairExecutionId,
            status: self.status
        )
    }

    /// Trader-facing ongoing orders exclude internal pool mirror legs.
    var isTraderFacingActiveOrder: Bool {
        if self.isMirrorPoolOrder == true { return false }
        if self.legType?.uppercased() == "MIRROR_POOL" { return false }
        return true
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

    func saveSellOrder(_ order: OrderSell, tradeId: String?) async throws -> OrderSell {
        print("📡 OrderAPIService: Saving sell order to Parse Server (tradeId: \(tradeId ?? "nil"))")

        let input = ParseOrderInput.from(sellOrder: order, tradeId: tradeId)
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

    func updateOrder(_ order: Order, tradeId: String?) async throws -> Order {
        print("📡 OrderAPIService: Updating order on Parse Server (status: \(order.status))")

        let input = ParseOrderInput.from(order: order, tradeId: tradeId)
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
            guard status != "completed" && status != "cancelled" else { return false }
            return order.isMirrorPoolOrder != true
        }
    }

    // MARK: - Cancel Order

    func cancelOrder(_ orderId: String) async throws {
        print("📡 OrderAPIService: Cancelling order via cloud function: \(orderId)")

        struct CancelOrderResponse: Decodable {
            let orderId: String?
            let pairExecutionId: String?
            let cancelledOrderIds: [String]?
            let cancelledLegCount: Int?
        }

        _ = try await self.apiClient.callFunction(
            "cancelOrder",
            parameters: ["orderId": orderId]
        ) as CancelOrderResponse

        print("✅ OrderAPIService: Order cancelled on server")
    }

    func finalizePairedBuyExecution(pairExecutionId: String) async throws {
        print("📡 OrderAPIService: Finalizing paired buy execution: \(pairExecutionId)")

        struct FinalizePairedBuyResponse: Decodable {
            let pairExecutionId: String?
            let status: String?
        }

        _ = try await self.apiClient.callFunction(
            "finalizePairedBuyExecution",
            parameters: ["pairExecutionId": pairExecutionId]
        ) as FinalizePairedBuyResponse

        print("✅ OrderAPIService: Paired buy finalized on server")
    }

    func commitPairedBuyExecution(pairExecutionId: String, postDisplayStatus: String? = nil) async throws {
        print("📡 OrderAPIService: Committing paired buy execution: \(pairExecutionId)")

        struct CommitPairedBuyResponse: Decodable {
            let pairExecutionId: String?
            let status: String?
            let postDisplayStatus: String?
        }

        var parameters: [String: Any] = ["pairExecutionId": pairExecutionId]
        if let postDisplayStatus, !postDisplayStatus.isEmpty {
            parameters["postDisplayStatus"] = postDisplayStatus
        }

        _ = try await self.apiClient.callFunction(
            "commitPairedBuyExecution",
            parameters: parameters
        ) as CommitPairedBuyResponse

        print("✅ OrderAPIService: Paired buy committed on server")
    }

    func advancePairedOrderStatus(pairExecutionId: String, status: String) async throws {
        print("📡 OrderAPIService: Advancing paired order status: \(pairExecutionId) → \(status)")

        struct AdvancePairedOrderStatusResponse: Decodable {
            let pairExecutionId: String?
            let status: String?
            let legCount: Int?
        }

        _ = try await self.apiClient.callFunction(
            "advancePairedOrderStatus",
            parameters: [
                "pairExecutionId": pairExecutionId,
                "status": status,
            ]
        ) as AdvancePairedOrderStatusResponse

        print("✅ OrderAPIService: Paired order legs advanced to \(status)")
    }
}
