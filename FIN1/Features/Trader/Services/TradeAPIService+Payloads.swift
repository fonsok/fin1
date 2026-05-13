import Foundation

extension TradeAPIService {
    func makeTradePayload(from trade: Trade, includeObjectId: Bool) -> [String: Any] {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var payload: [String: Any] = [
            "tradeNumber": trade.tradeNumber,
            "traderId": trade.traderId,
            "symbol": trade.symbol,
            "description": trade.description,
            "status": trade.status.rawValue,
            "buyOrder": self.makeBuyOrderPayload(from: trade.buyOrder)
        ]

        if includeObjectId { payload["objectId"] = trade.id }
        if let calculatedProfit = trade.calculatedProfit { payload["calculatedProfit"] = calculatedProfit }
        if let completedAt = trade.completedAt { payload["completedAt"] = dateFormatter.string(from: completedAt) }
        if let sellOrder = trade.sellOrder { payload["sellOrder"] = self.makeSellOrderPayload(from: sellOrder) }
        if !trade.sellOrders.isEmpty { payload["sellOrders"] = trade.sellOrders.map { self.makeSellOrderPayload(from: $0) } }
        return payload
    }

    func makeBuyOrderPayload(from order: OrderBuy) -> [String: Any] {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return [
            "id": order.id,
            "traderId": order.traderId,
            "symbol": order.symbol,
            "description": order.description,
            "quantity": order.quantity,
            "price": order.price,
            "totalAmount": order.totalAmount,
            "status": order.status.rawValue,
            "createdAt": dateFormatter.string(from: order.createdAt),
            "executedAt": order.executedAt.map { dateFormatter.string(from: $0) } as Any,
            "confirmedAt": order.confirmedAt.map { dateFormatter.string(from: $0) } as Any,
            "updatedAt": dateFormatter.string(from: order.updatedAt),
            "optionDirection": order.optionDirection as Any,
            "underlyingAsset": order.underlyingAsset as Any,
            "wkn": order.wkn as Any,
            "category": order.category as Any,
            "strike": order.strike as Any,
            "orderInstruction": order.orderInstruction as Any,
            "limitPrice": order.limitPrice as Any
        ]
    }

    func makeSellOrderPayload(from order: OrderSell) -> [String: Any] {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return [
            "id": order.id,
            "traderId": order.traderId,
            "symbol": order.symbol,
            "description": order.description,
            "quantity": order.quantity,
            "price": order.price,
            "totalAmount": order.totalAmount,
            "status": order.status.rawValue,
            "createdAt": dateFormatter.string(from: order.createdAt),
            "executedAt": order.executedAt.map { dateFormatter.string(from: $0) } as Any,
            "confirmedAt": order.confirmedAt.map { dateFormatter.string(from: $0) } as Any,
            "updatedAt": dateFormatter.string(from: order.updatedAt),
            "optionDirection": order.optionDirection as Any,
            "underlyingAsset": order.underlyingAsset as Any,
            "wkn": order.wkn as Any,
            "category": order.category as Any,
            "strike": order.strike as Any,
            "orderInstruction": order.orderInstruction as Any,
            "limitPrice": order.limitPrice as Any,
            "originalHoldingId": order.originalHoldingId as Any
        ]
    }
}

// MARK: - Parse Trade Input Model
private struct ParseTradeInput: Codable {
    let tradeNumber: Int
    let traderId: String
    let symbol: String
    let description: String
    let status: String
    let calculatedProfit: Double?
    let completedAt: String?
    let buyOrder: ParseOrderBuyInput
    let sellOrder: ParseOrderSellInput?
    let sellOrders: [ParseOrderSellInput]?

    static func from(trade: Trade) -> ParseTradeInput {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return ParseTradeInput(
            tradeNumber: trade.tradeNumber,
            traderId: trade.traderId,
            symbol: trade.symbol,
            description: trade.description,
            status: trade.status.rawValue,
            calculatedProfit: trade.calculatedProfit,
            completedAt: trade.completedAt.map { dateFormatter.string(from: $0) },
            buyOrder: ParseOrderBuyInput.from(order: trade.buyOrder),
            sellOrder: trade.sellOrder.map { ParseOrderSellInput.from(order: $0) },
            sellOrders: trade.sellOrders.isEmpty ? nil : trade.sellOrders.map { ParseOrderSellInput.from(order: $0) }
        )
    }
}

private struct ParseOrderBuyInput: Codable {
    let id: String
    let traderId: String
    let symbol: String
    let description: String
    let quantity: Double
    let price: Double
    let totalAmount: Double
    let status: String
    let createdAt: String
    let executedAt: String?
    let confirmedAt: String?
    let updatedAt: String
    let optionDirection: String?
    let underlyingAsset: String?
    let wkn: String?
    let category: String?
    let strike: Double?
    let orderInstruction: String?
    let limitPrice: Double?

    static func from(order: OrderBuy) -> ParseOrderBuyInput {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return ParseOrderBuyInput(
            id: order.id,
            traderId: order.traderId,
            symbol: order.symbol,
            description: order.description,
            quantity: order.quantity,
            price: order.price,
            totalAmount: order.totalAmount,
            status: order.status.rawValue,
            createdAt: dateFormatter.string(from: order.createdAt),
            executedAt: order.executedAt.map { dateFormatter.string(from: $0) },
            confirmedAt: order.confirmedAt.map { dateFormatter.string(from: $0) },
            updatedAt: dateFormatter.string(from: order.updatedAt),
            optionDirection: order.optionDirection,
            underlyingAsset: order.underlyingAsset,
            wkn: order.wkn,
            category: order.category,
            strike: order.strike,
            orderInstruction: order.orderInstruction,
            limitPrice: order.limitPrice
        )
    }
}

private struct ParseOrderSellInput: Codable {
    let id: String
    let traderId: String
    let symbol: String
    let description: String
    let quantity: Double
    let price: Double
    let totalAmount: Double
    let status: String
    let createdAt: String
    let executedAt: String?
    let confirmedAt: String?
    let updatedAt: String
    let optionDirection: String?
    let underlyingAsset: String?
    let wkn: String?
    let category: String?
    let strike: Double?
    let orderInstruction: String?
    let limitPrice: Double?
    let originalHoldingId: String?

    static func from(order: OrderSell) -> ParseOrderSellInput {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return ParseOrderSellInput(
            id: order.id,
            traderId: order.traderId,
            symbol: order.symbol,
            description: order.description,
            quantity: order.quantity,
            price: order.price,
            totalAmount: order.totalAmount,
            status: order.status.rawValue,
            createdAt: dateFormatter.string(from: order.createdAt),
            executedAt: order.executedAt.map { dateFormatter.string(from: $0) },
            confirmedAt: order.confirmedAt.map { dateFormatter.string(from: $0) },
            updatedAt: dateFormatter.string(from: order.updatedAt),
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
}
