import Foundation

let mockDepotValue: Double = 123456.78
let mockDepotNumber: String = "555556666"

let mockRunningTransactions: [Order] = []

// MARK: - DepotHolding Model
/// Represents holdings in the depot with split option information
/// This is the final state after completed trades are moved to holdings
struct DepotHolding: Identifiable {
    let id = UUID()
    let orderId: String? // Reference to original buy order for invoice generation
    let position: Int
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

    init(
        orderId: String?,
        position: Int,
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
        subscriptionRatio: Double? = nil
    ) {
        self.orderId = orderId
        self.position = position
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
    }

    // Computed properties for partial sales
    var isPartiallySold: Bool {
        return soldQuantity > 0 && soldQuantity < originalQuantity
    }

    var isFullySold: Bool {
        return soldQuantity >= originalQuantity
    }

    var sellProgressPercentage: Double {
        guard originalQuantity > 0 else { return 0.0 }
        return Double(soldQuantity) / Double(originalQuantity) * 100.0
    }

    // Architecture: DepotHolding represents holdings with split option information
    // This is where completed orders (Order) end up after buy orders are completed
    // and the position is moved from "running orders" to "holdings"

    /// Creates a DepotHolding from a completed OrderBuy
    /// This represents the final state when an order is completed and moved to holdings
    static func from(completedOrder: OrderBuy, position: Int) -> DepotHolding {
        let designation: String
        if let optionDirection = completedOrder.optionDirection, let underlyingAsset = completedOrder.underlyingAsset {
            designation = "\(optionDirection) - \(underlyingAsset)"
        } else {
            designation = completedOrder.description
        }

        let quantity = Int(completedOrder.quantity)
        return DepotHolding(
            orderId: completedOrder.id,
            position: position,
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
            position: self.position,
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
            subscriptionRatio: self.subscriptionRatio
        )
    }
}

let mockDepotHoldings: [DepotHolding] = []
