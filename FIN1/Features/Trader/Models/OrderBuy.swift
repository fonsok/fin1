import Foundation

// MARK: - Order Buy Model
/// Individual buy transactions with status progression (submitted → executed → completed)
struct OrderBuy: Identifiable, Codable {
    let id: String
    let traderId: String
    let symbol: String
    let description: String
    let quantity: Double
    let price: Double
    let totalAmount: Double
    let status: OrderBuyStatus
    let createdAt: Date
    let executedAt: Date?
    let confirmedAt: Date?
    let updatedAt: Date

    // Warrant-specific fields (Optionsscheine)
    let optionDirection: String? // "CALL" or "PUT" for warrants
    let underlyingAsset: String? // "DAX"
    let wkn: String? // WKN number
    let category: String? // Product category like "Optionsschein", "Knockout", etc.
    let strike: Double? // Strike price for warrants

    // Order instruction fields
    let orderInstruction: String? // "market" or "limit"
    let limitPrice: Double? // Limit price for limit orders
    let subscriptionRatio: Double? // Units-per-share ratio snapshot
    let denomination: Int? // Issuer-provided denomination constraint

    init(
        id: String,
        traderId: String,
        symbol: String,
        description: String,
        quantity: Double,
        price: Double,
        totalAmount: Double,
        status: OrderBuyStatus,
        createdAt: Date,
        executedAt: Date?,
        confirmedAt: Date?,
        updatedAt: Date,
        optionDirection: String?,
        underlyingAsset: String?,
        wkn: String?,
        category: String?,
        strike: Double?,
        orderInstruction: String?,
        limitPrice: Double?,
        subscriptionRatio: Double? = nil,
        denomination: Int? = nil
    ) {
        self.id = id
        self.traderId = traderId
        self.symbol = symbol
        self.description = description
        self.quantity = quantity
        self.price = price
        self.totalAmount = totalAmount
        self.status = status
        self.createdAt = createdAt
        self.executedAt = executedAt
        self.confirmedAt = confirmedAt
        self.updatedAt = updatedAt
        self.optionDirection = optionDirection
        self.underlyingAsset = underlyingAsset
        self.wkn = wkn
        self.category = category
        self.strike = strike
        self.orderInstruction = orderInstruction
        self.limitPrice = limitPrice
        self.subscriptionRatio = subscriptionRatio
        self.denomination = denomination
    }

    // MARK: - Computed Properties

    var isActive: Bool {
        status == .submitted || status == .executed
    }

    var isCompleted: Bool {
        status == .completed
    }

    var isInHoldings: Bool {
        status == .completed
    }
}

// MARK: - Conversion from Order

extension OrderBuy {
    /// Creates an OrderBuy from a generic Order
    init(from order: Order) {
        self.init(
            id: order.id,
            traderId: order.traderId,
            symbol: order.symbol,
            description: order.description,
            quantity: order.quantity,
            price: order.price,
            totalAmount: order.totalAmount,
            status: order.type == .buy ? .completed : .submitted,
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
}











