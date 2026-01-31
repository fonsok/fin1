import Foundation

// MARK: - Investment Quantity Calculation Service Protocol

/// Service for calculating the maximum quantity of securities that can be purchased
/// with a given investment balance, accounting for trading fees
protocol InvestmentQuantityCalculationServiceProtocol {
    /// Calculates the maximum quantity of securities that can be purchased with investment balance
    /// - Parameters:
    ///   - investmentBalance: Available investment balance in EUR
    ///   - pricePerSecurity: Price per security (share) in EUR
    ///   - denomination: Optional denomination constraint (e.g., 1, 10, 100). If nil, no denomination restriction.
    ///   - subscriptionRatio: Subscription ratio (e.g., 1.0, 0.1, 0.01, 10.0, 100.0). Represents units per share (1:1, 1:10, 1:100). Default is 1.0.
    ///   - minimumOrderAmount: Optional minimum order amount in EUR. If specified, order must meet or exceed this amount.
    /// - Returns: Maximum purchasable quantity in units (integer), rounded down to valid denomination if specified, or 0 if minimum order amount cannot be met
    func calculateMaxPurchasableQuantity(
        investmentBalance: Double,
        pricePerSecurity: Double,
        denomination: Int?,
        subscriptionRatio: Double,
        minimumOrderAmount: Double?
    ) -> Int

    /// Calculates the combined order details for trader + investment purchase
    /// The total executed quantity = trader's quantity + investment's purchasable quantity
    /// - Parameters:
    ///   - traderQuantity: Trader's desired quantity in units (paid from trader's cash balance)
    ///   - traderCashBalance: Trader's available cash balance
    ///   - investmentBalance: Available investment balance in EUR
    ///   - pricePerSecurity: Price per security (share) in EUR
    ///   - denomination: Optional denomination constraint (e.g., 1, 10, 100). If nil, no denomination restriction.
    ///   - subscriptionRatio: Subscription ratio (e.g., 1.0, 0.1, 0.01, 10.0, 100.0). Represents units per share (1:1, 1:10, 1:100). Default is 1.0.
    ///   - minimumOrderAmount: Optional minimum order amount in EUR. If specified, total order must meet or exceed this amount.
    /// - Returns: Combined order details with total quantity, split costs, fees, and residual amounts
    func calculateCombinedOrderDetails(
        traderQuantity: Int,
        traderCashBalance: Double,
        investmentBalance: Double,
        pricePerSecurity: Double,
        denomination: Int?,
        subscriptionRatio: Double,
        minimumOrderAmount: Double?
    ) -> CombinedOrderCalculationResult
}

// MARK: - Combined Order Calculation Result

/// Result of combined trader + investment order calculation
struct CombinedOrderCalculationResult {
    /// Trader's quantity (from trader's cash balance)
    let traderQuantity: Int

    /// Investment's purchasable quantity (from investment balance)
    let investmentQuantity: Int

    /// Total executed quantity (trader + investment)
    let totalQuantity: Int

    /// Trader's order amount (traderQuantity × price)
    let traderOrderAmount: Double

    /// Investment's order amount (investmentQuantity × price)
    let investmentOrderAmount: Double

    /// Total order amount (totalQuantity × price)
    let totalOrderAmount: Double

    /// Total fees for the combined order
    let totalFees: Double

    /// Trader's share of fees (proportional to trader's order amount)
    let traderFees: Double

    /// Investment's share of fees (proportional to investment's order amount)
    let investmentFees: Double

    /// Trader's total cost (order amount + fees)
    let traderTotalCost: Double

    /// Investment's total cost (order amount + fees)
    let investmentTotalCost: Double

    /// Total cost (trader + investment)
    let totalCost: Double

    /// Trader's remaining cash balance after purchase
    let traderRemainingBalance: Double

    /// Investment's remaining balance after purchase
    let investmentRemainingBalance: Double

    /// True if trader's cash balance is insufficient for desired quantity
    let isTraderLimited: Bool

    /// True if investment balance limits the investment quantity
    let isInvestmentLimited: Bool

    /// Detailed fee breakdown for the total order
    let feeBreakdown: [FeeDetail]

    /// Residual amount in investment pool that cannot purchase a full denomination
    /// This occurs when investment funds are insufficient to buy the next valid denomination unit
    let investmentResidualAmount: Double

    /// Number of shares (calculated from units using subscription ratio)
    let totalShares: Int

    /// Trader's quantity in shares
    let traderShares: Int

    /// Investment's quantity in shares
    let investmentShares: Int
}
