import Foundation

/// Parse Server representation of a Trade
/// Maps between Parse format and app Trade model
struct ParseTrade: Codable {
    let objectId: String
    let tradeNumber: Int
    let traderId: String
    let symbol: String
    let description: String
    let status: String
    let createdAt: String
    let updatedAt: String
    let completedAt: String?
    let calculatedProfit: Double?
    let buyOrder: ParseOrderBuy
    let sellOrder: ParseOrderSell?
    let sellOrders: [ParseOrderSell]?

    enum CodingKeys: String, CodingKey {
        case objectId, tradeNumber, traderId, symbol, description, status
        case createdAt, updatedAt, completedAt, calculatedProfit
        case buyOrder, sellOrder, sellOrders
    }

    func toTrade() throws -> Trade {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let createdDate = dateFormatter.date(from: createdAt) ?? Date()
        let updatedDate = dateFormatter.date(from: updatedAt) ?? Date()
        let completedDate = completedAt.flatMap { dateFormatter.date(from: $0) }
        let tradeStatus = TradeStatus(rawValue: status) ?? .pending

        let buyOrderModel = try buyOrder.toOrderBuy()
        let sellOrderModel = sellOrder.flatMap { try? $0.toOrderSell() }
        let sellOrdersModel = (sellOrders ?? []).compactMap { try? $0.toOrderSell() }

        return Trade(
            id: objectId,
            tradeNumber: tradeNumber,
            traderId: traderId,
            symbol: symbol,
            description: description,
            buyOrder: buyOrderModel,
            sellOrder: sellOrderModel,
            sellOrders: sellOrdersModel,
            status: tradeStatus,
            createdAt: createdDate,
            completedAt: completedDate,
            updatedAt: updatedDate,
            calculatedProfit: calculatedProfit
        )
    }
}

struct ParseOrderBuy: Codable {
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

    func toOrderBuy() throws -> OrderBuy {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let createdDate = dateFormatter.date(from: createdAt) ?? Date()
        let updatedDate = dateFormatter.date(from: updatedAt) ?? Date()
        let executedDate = executedAt.flatMap { dateFormatter.date(from: $0) }
        let confirmedDate = confirmedAt.flatMap { dateFormatter.date(from: $0) }
        let orderStatus = OrderBuyStatus(rawValue: status) ?? .submitted

        return OrderBuy(
            id: id,
            traderId: traderId,
            symbol: symbol,
            description: description,
            quantity: quantity,
            price: price,
            totalAmount: totalAmount,
            status: orderStatus,
            createdAt: createdDate,
            executedAt: executedDate,
            confirmedAt: confirmedDate,
            updatedAt: updatedDate,
            optionDirection: optionDirection,
            underlyingAsset: underlyingAsset,
            wkn: wkn,
            category: category,
            strike: strike,
            orderInstruction: orderInstruction,
            limitPrice: limitPrice
        )
    }
}

struct ParseOrderSell: Codable {
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

    func toOrderSell() throws -> OrderSell {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let createdDate = dateFormatter.date(from: createdAt) ?? Date()
        let updatedDate = dateFormatter.date(from: updatedAt) ?? Date()
        let executedDate = executedAt.flatMap { dateFormatter.date(from: $0) }
        let confirmedDate = confirmedAt.flatMap { dateFormatter.date(from: $0) }
        let orderStatus = OrderSellStatus(rawValue: status) ?? .submitted

        return OrderSell(
            id: id,
            traderId: traderId,
            symbol: symbol,
            description: description,
            quantity: quantity,
            price: price,
            totalAmount: totalAmount,
            status: orderStatus,
            createdAt: createdDate,
            executedAt: executedDate,
            confirmedAt: confirmedDate,
            updatedAt: updatedDate,
            optionDirection: optionDirection,
            underlyingAsset: underlyingAsset,
            wkn: wkn,
            category: category,
            strike: strike,
            orderInstruction: orderInstruction,
            limitPrice: limitPrice,
            originalHoldingId: originalHoldingId
        )
    }
}
