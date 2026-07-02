import Foundation

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
