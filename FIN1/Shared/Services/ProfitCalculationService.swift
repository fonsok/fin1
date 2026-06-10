import Foundation

// MARK: - Profit Calculation Service

/// Centralized service for calculating actual trading profit/loss amounts (monetary values in currency)
///
/// **Terminology Distinction:**
/// - **Profit** (this service): Actual monetary amounts (e.g., 100.50 EUR) - sell proceeds minus buy costs
/// - **Return**: Percentage-based metrics (e.g., 15.5%) - ROI calculations
///
/// This service calculates actual profit/loss amounts, not return percentages.
final class ProfitCalculationService {

    // MARK: - Public Methods

    /// Full-trade taxable profit from invoices (100 % sell — backward-compatible alias).
    static func calculateTaxableProfit(buyInvoice: Invoice?, sellInvoices: [Invoice]) -> Double {
        self.calculateRealizedTaxableProfit(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices,
            soldQuantity: .infinity,
            buyQuantity: 1
        )
    }

    /// Realized taxable profit: Σ sell invoices − allocated buy invoice cost.
    /// Partial sell: buy cost scaled by `soldQuantity / buyQuantity`.
    static func calculateRealizedTaxableProfit(
        buyInvoice: Invoice?,
        sellInvoices: [Invoice],
        soldQuantity: Double,
        buyQuantity: Double
    ) -> Double {
        let sellTotal = sellInvoices
            .filter { $0.transactionType == .sell }
            .reduce(0) { $0 + $1.nonTaxTotal }

        guard let buyInvoice, buyQuantity > 0, soldQuantity > 0 else {
            return sellTotal
        }

        let buyTotal = buyInvoice.nonTaxTotal
        let allocatedBuy = soldQuantity >= buyQuantity
            ? buyTotal
            : buyTotal * (soldQuantity / buyQuantity)
        return sellTotal - allocatedBuy
    }

    /// Calculates net cash flow from buy and sell invoices (including taxes)
    /// - Parameters:
    ///   - buyInvoice: The buy transaction invoice
    ///   - sellInvoices: Array of sell transaction invoices
    /// - Returns: Net cash flow amount
    static func calculateNetCashFlow(buyInvoice: Invoice?, sellInvoices: [Invoice]) -> Double {
        let allInvoices = [buyInvoice].compactMap { $0 } + sellInvoices
        let buyInvoices = allInvoices.filter { $0.transactionType == .buy }
        let sellInvoices = allInvoices.filter { $0.transactionType == .sell }

        let buyAmount = -buyInvoices.reduce(0) { $0 + $1.totalAmount } // Negative because money goes out
        let sellAmount = sellInvoices.reduce(0) { $0 + $1.totalAmount } // Positive because money comes in

        return buyAmount + sellAmount
    }

    /// Order-based realized gross profit (fee-aware). Delegates to proportional allocation.
    static func calculateGrossProfitFromOrders(for trade: Trade) -> Double {
        self.calculateRealizedGrossProfitFromOrders(for: trade)
    }

    /// Realized gross profit from order legs: net sell proceeds − allocated buy cost.
    static func calculateRealizedGrossProfitFromOrders(for trade: Trade) -> Double {
        let sellOrders = trade.sellOrders.isEmpty ? (trade.sellOrder.map { [$0] } ?? []) : trade.sellOrders
        guard !sellOrders.isEmpty else { return 0.0 }

        let soldQuantity = sellOrders.reduce(0) { $0 + $1.quantity }
        let buyQuantity = trade.buyOrder.quantity
        guard soldQuantity > 0, buyQuantity > 0 else { return 0.0 }

        let fullBuySecurities = trade.buyOrder.price * buyQuantity
        let fullBuyFees = FeeCalculationService.calculateTotalFees(for: fullBuySecurities)
        let fullBuyCost = fullBuySecurities + fullBuyFees
        let allocatedBuyCost = soldQuantity >= buyQuantity
            ? fullBuyCost
            : fullBuyCost * (soldQuantity / buyQuantity)

        let sellSecuritiesValue = sellOrders.reduce(0) { $0 + ($1.price * $1.quantity) }
        let sellFees = sellOrders.reduce(0) { total, order in
            let orderAmount = order.price * order.quantity
            return total + FeeCalculationService.calculateTotalFees(for: orderAmount)
        }
        let sellNetProceeds = sellSecuritiesValue - sellFees

        return sellNetProceeds - allocatedBuyCost
    }

    /// Matches backend `resolveTradeRealizedGrossProfit` using embedded order `totalAmount` snapshots.
    static func calculateRealizedGrossProfitFromOrderTotals(for trade: Trade) -> Double? {
        let sellOrders = trade.sellOrders.isEmpty ? (trade.sellOrder.map { [$0] } ?? []) : trade.sellOrders
        guard !sellOrders.isEmpty else { return nil }

        let sellTotal = sellOrders.reduce(0) { $0 + $1.totalAmount }
        guard sellTotal > 0 else { return nil }

        let buyTotal = trade.buyOrder.totalAmount
        let soldQuantity = trade.totalSoldQuantity
        let buyQuantity = trade.buyOrder.quantity
        guard buyTotal > 0, buyQuantity > 0, soldQuantity > 0 else { return nil }

        let allocatedBuy = soldQuantity >= buyQuantity
            ? buyTotal
            : buyTotal * (soldQuantity / buyQuantity)
        return sellTotal - allocatedBuy
    }

    /// Write-time SSOT: order totals (Parse snapshots) → invoices → fee-based order legs.
    static func resolveRealizedProfit(
        for trade: Trade,
        buyInvoice: Invoice? = nil,
        sellInvoices: [Invoice] = []
    ) -> Double? {
        guard trade.totalSoldQuantity > 0 else { return nil }

        if let totalsProfit = self.calculateRealizedGrossProfitFromOrderTotals(for: trade) {
            return totalsProfit
        }

        if let buyInvoice, !sellInvoices.isEmpty {
            return self.calculateRealizedTaxableProfit(
                buyInvoice: buyInvoice,
                sellInvoices: sellInvoices,
                soldQuantity: trade.totalSoldQuantity,
                buyQuantity: trade.buyOrder.quantity
            )
        }

        return self.calculateRealizedGrossProfitFromOrders(for: trade)
    }

    /// True when stored profit diverges from order-leg totals (stale first partial-sell snapshot).
    static func isStoredProfitStale(for trade: Trade) -> Bool {
        guard let stored = trade.calculatedProfit,
              let expected = self.calculateRealizedGrossProfitFromOrderTotals(for: trade) else {
            return false
        }
        return abs(stored - expected) > 0.01
    }

    /// Persists realized profit on the trade (immutable update).
    static func tradeWithStoredRealizedProfit(
        _ trade: Trade,
        buyInvoice: Invoice? = nil,
        sellInvoices: [Invoice] = []
    ) -> Trade {
        guard let profit = self.resolveRealizedProfit(
            for: trade,
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices
        ) else {
            return trade
        }
        return trade.withCalculatedProfit(profit)
    }

    /// Calculates profit before taxes from transaction details
    /// - Parameters:
    ///   - buyTransaction: Buy transaction details
    ///   - sellTransactions: Array of sell transaction details
    /// - Returns: Profit before taxes amount
    static func calculateProfitBeforeTaxes(
        buyTransaction: TransactionDetails?,
        sellTransactions: [TransactionDetails]
    ) -> Double {
        let buyAmount = buyTransaction?.subtotal ?? 0
        let sellAmount = sellTransactions.reduce(0) { $0 + $1.subtotal }
        return sellAmount - buyAmount
    }

    /// Calculates investor's proportional taxable profit from invoices
    /// Uses the same invoice-based calculation as trader but scaled by ownership percentage
    /// This ensures trader ROI and investor return use identical calculation methods
    /// - Parameters:
    ///   - buyInvoice: The buy transaction invoice
    ///   - sellInvoices: Array of sell transaction invoices
    ///   - ownershipPercentage: Investor's ownership percentage (0.0 to 1.0)
    /// - Returns: Investor's proportional taxable profit amount
    static func calculateInvestorTaxableProfit(
        buyInvoice: Invoice?,
        sellInvoices: [Invoice],
        ownershipPercentage: Double
    ) -> Double {
        // Calculate full trade profit using invoice-based method (same as trader)
        let fullTradeProfit = self.calculateTaxableProfit(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices
        )

        // Scale proportionally by ownership percentage
        // This ensures: (profit × ownership%) / (denominator × ownership%) = profit / denominator
        return fullTradeProfit * ownershipPercentage
    }

    // MARK: - Return Percentage Calculation

    /// Calculates return percentage (ROI) from gross profit and invested amount
    /// This is the single source of truth for return percentage calculations
    /// Used by both trader and investor calculations to ensure consistency
    /// Note: "ROI" (Return on Investment) and "return percentage" refer to the same concept
    /// - Parameters:
    ///   - grossProfit: Gross profit amount (numerator)
    ///   - investedAmount: Invested amount (denominator) - pure securities value, no fees
    /// - Returns: Return percentage (e.g., 98.05 for 98.05%), or nil if investedAmount is zero or negative
    static func calculateReturnPercentage(
        grossProfit: Double,
        investedAmount: Double
    ) -> Double? {
        guard investedAmount > 0 else { return nil }
        return (grossProfit / investedAmount) * 100
    }
}

// MARK: - Transaction Details Model

/// Represents transaction details for profit calculation
struct TransactionDetails {
    let type: CalculationTransactionType
    let quantity: Double
    let price: Double
    let amount: Double
    let fees: [FeeDetail]
    let subtotal: Double
}

// MARK: - Calculation Transaction Type

enum CalculationTransactionType {
    case buy
    case sell

    var displayName: String {
        switch self {
        case .buy:
            return "Kauf"
        case .sell:
            return "Verkauf"
        }
    }
}
