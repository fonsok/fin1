import Foundation

/// Input struct for creating/updating orders on Parse Server (matches Order beforeSave schema).
struct ParseOrderInput: Codable {
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
