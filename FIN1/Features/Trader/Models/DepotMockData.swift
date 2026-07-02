import Foundation

let mockDepotValue: Double = 123_456.78
let mockDepotNumber: String = "555556666"

let mockRunningTransactions: [Order] = []

// MARK: - DepotHolding Model
/// Represents holdings in the depot with split option information
/// This is the final state after completed trades are moved to holdings
struct DepotHolding: Identifiable {
    let id = UUID()
    let orderId: String? // Reference to original buy order for invoice generation
    /// Parse Trade objectId for the trader leg shown in depot (SSOT for pool status per position).
    let tradeId: String
    /// Set when buy used `executePairedBuy`; links TRADER + MIRROR_POOL legs.
    let pairExecutionId: String?
    let position: Int
    /// Trader trade number (001, 002, …) for depot position label.
    let tradeNumber: Int?
    /// Calendar year for annual trade-number reset (e.g. 2026 → 2026-001).
    let tradeNumberYear: Int?
    var formattedTradeNumberLabel: String? {
        guard let tradeNumber, tradeNumber > 0 else { return nil }
        let label = TradeNumberFormatting.display(number: tradeNumber, year: self.tradeNumberYear)
        return label.isEmpty ? nil : label
    }

    let valuationDate: String
    let wkn: String
    let strike: Double
    let designation: String
    let direction: String? // Call/Put for Optionsscheine
    let underlyingAsset: String? // DAX, Apple, etc.
    let purchasePrice: Double
    let currentPrice: Double
    let quantity: Int // Original total quantity from buy order

    // MARK: - Partial Sales Support
    let originalQuantity: Int // Original quantity from buy order
    let soldQuantity: Int // Total quantity sold through partial sales
    let remainingQuantity: Int // Available quantity for selling
    let totalValue: Double
    let denomination: Int?
    let subscriptionRatio: Double?
    /// Server SSOT (`Trade.traderPartialSellEventCount`) — für Teil-Verkaufs-Limit UI.
    let traderPartialSellEventCount: Int?

    init(
        orderId: String?,
        tradeId: String = "",
        pairExecutionId: String? = nil,
        position: Int,
        tradeNumber: Int? = nil,
        tradeNumberYear: Int? = nil,
        valuationDate: String,
        wkn: String,
        strike: Double,
        designation: String,
        direction: String?,
        underlyingAsset: String?,
        purchasePrice: Double,
        currentPrice: Double,
        quantity: Int,
        originalQuantity: Int,
        soldQuantity: Int,
        remainingQuantity: Int,
        totalValue: Double,
        denomination: Int? = nil,
        subscriptionRatio: Double? = nil,
        traderPartialSellEventCount: Int? = nil
    ) {
        self.orderId = orderId
        self.tradeId = tradeId
        self.pairExecutionId = pairExecutionId
        self.position = position
        self.tradeNumber = tradeNumber
        self.tradeNumberYear = tradeNumberYear
        self.valuationDate = valuationDate
        self.wkn = wkn
        self.strike = strike
        self.designation = designation
        self.direction = direction
        self.underlyingAsset = underlyingAsset
        self.purchasePrice = purchasePrice
        self.currentPrice = currentPrice
        self.quantity = quantity
        self.originalQuantity = originalQuantity
        self.soldQuantity = soldQuantity
        self.remainingQuantity = remainingQuantity
        self.totalValue = totalValue
        self.denomination = denomination
        self.subscriptionRatio = subscriptionRatio
        self.traderPartialSellEventCount = traderPartialSellEventCount
    }

    // Computed properties for partial sales
    var isPartiallySold: Bool {
        return self.soldQuantity > 0 && self.soldQuantity < self.originalQuantity
    }

    var isFullySold: Bool {
        return self.soldQuantity >= self.originalQuantity
    }

    var sellProgressPercentage: Double {
        guard self.originalQuantity > 0 else { return 0.0 }
        return Double(self.soldQuantity) / Double(self.originalQuantity) * 100.0
    }

    // Architecture: DepotHolding represents holdings with split option information
    // This is where completed orders (Order) end up after buy orders are completed
    // and the position is moved from "running orders" to "holdings"

    /// Creates a DepotHolding from a completed OrderBuy
    /// This represents the final state when an order is completed and moved to holdings
    static func from(
        completedOrder: OrderBuy,
        position: Int,
        tradeId: String? = nil,
        pairExecutionId: String? = nil,
        tradeNumber: Int? = nil,
        tradeNumberYear: Int? = nil
    ) -> DepotHolding {
        let designation: String
        if let optionDirection = completedOrder.optionDirection, let underlyingAsset = completedOrder.underlyingAsset {
            designation = "\(optionDirection) - \(underlyingAsset)"
        } else {
            designation = completedOrder.description
        }

        let quantity = Int(completedOrder.quantity)
        return DepotHolding(
            orderId: completedOrder.id,
            tradeId: tradeId ?? completedOrder.id,
            pairExecutionId: pairExecutionId,
            position: position,
            tradeNumber: tradeNumber,
            tradeNumberYear: tradeNumberYear,
            valuationDate: Date().formatted(date: .numeric, time: .omitted),
            wkn: completedOrder.wkn ?? completedOrder.symbol,
            strike: completedOrder.strike ?? 0.0,
            designation: designation,
            direction: completedOrder.optionDirection,
            underlyingAsset: completedOrder.underlyingAsset,
            purchasePrice: completedOrder.price,
            currentPrice: completedOrder.price, // For buy orders, both are the same
            quantity: quantity,
            originalQuantity: quantity,
            soldQuantity: 0,
            remainingQuantity: quantity,
            totalValue: completedOrder.totalAmount,
            denomination: completedOrder.denomination,
            subscriptionRatio: completedOrder.subscriptionRatio
        )
    }

    /// Creates a new DepotHolding with updated partial sale information
    func withPartialSale(soldQuantity: Int) -> DepotHolding {
        let newSoldQuantity = self.soldQuantity + soldQuantity
        let newRemainingQuantity = max(0, originalQuantity - newSoldQuantity)

        return DepotHolding(
            orderId: self.orderId,
            tradeId: self.tradeId,
            pairExecutionId: self.pairExecutionId,
            position: self.position,
            tradeNumber: self.tradeNumber,
            tradeNumberYear: self.tradeNumberYear,
            valuationDate: self.valuationDate,
            wkn: self.wkn,
            strike: self.strike,
            designation: self.designation,
            direction: self.direction,
            underlyingAsset: self.underlyingAsset,
            purchasePrice: self.purchasePrice,
            currentPrice: self.currentPrice,
            quantity: self.quantity,
            originalQuantity: self.originalQuantity,
            soldQuantity: newSoldQuantity,
            remainingQuantity: newRemainingQuantity,
            totalValue: self.totalValue,
            denomination: self.denomination,
            subscriptionRatio: self.subscriptionRatio,
            traderPartialSellEventCount: self.traderPartialSellEventCount
        )
    }
}

let mockDepotHoldings: [DepotHolding] = []
