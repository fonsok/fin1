import Foundation

// MARK: - Order Sell Model
/// Individual sell transactions with status progression (submitted → executed → confirmed)
struct OrderSell: Identifiable, Codable, Sendable {
    let id: String
    let traderId: String
    let symbol: String
    let description: String
    let quantity: Double
    let price: Double
    let totalAmount: Double
    let status: OrderSellStatus
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

    // Reference to original holding
    let originalHoldingId: String?

    // MARK: - Computed Properties

    var isActive: Bool {
        status == .submitted || status == .executed
    }

    var isCompleted: Bool {
        status == .confirmed
    }
}

// MARK: - Conversion from Order

extension OrderSell {
    /// Creates an OrderSell from a generic Order
    init(from order: Order) {
        self.init(
            id: order.id,
            traderId: order.traderId,
            symbol: order.symbol,
            description: order.description,
            quantity: order.quantity,
            price: order.price,
            totalAmount: order.totalAmount,
            status: order.type == .sell ? .confirmed : .submitted,
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
}











