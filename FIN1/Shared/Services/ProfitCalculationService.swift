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

    /// Calculates taxable profit from buy and sell invoices (excluding taxes)
    /// This is the most accurate method as it uses actual invoice data
    /// - Parameters:
    ///   - buyInvoice: The buy transaction invoice
    ///   - sellInvoices: Array of sell transaction invoices
    /// - Returns: Taxable profit amount
    static func calculateTaxableProfit(buyInvoice: Invoice?, sellInvoices: [Invoice]) -> Double {
        let allInvoices = [buyInvoice].compactMap { $0 } + sellInvoices
        let buyInvoices = allInvoices.filter { $0.transactionType == .buy }
        let sellInvoices = allInvoices.filter { $0.transactionType == .sell }

        // Calculate total buy amount (positive value representing money spent)
        let totalBuyAmount = buyInvoices.reduce(0) { total, invoice in
            return total + invoice.nonTaxTotal
        }

        // Calculate total sell amount (positive value representing money received)
        let totalSellAmount = sellInvoices.reduce(0) { total, invoice in
            return total + invoice.nonTaxTotal
        }

        // Taxable profit = sell proceeds - buy costs
        return totalSellAmount - totalBuyAmount
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

    /// Calculates gross profit from trade orders (order-based calculation)
    /// - Parameter trade: The trade object
    /// - Returns: Gross profit amount
    static func calculateGrossProfitFromOrders(for trade: Trade) -> Double {
        // Check both legacy sellOrder and new sellOrders array
        let sellOrders = trade.sellOrders.isEmpty ? (trade.sellOrder.map { [$0] } ?? []) : trade.sellOrders

        guard !sellOrders.isEmpty else {
            return 0.0
        }

        // Use the same calculation logic as invoice-based calculation for consistency
        // This ensures both "Überblick Trades-Profit" and "Collection Bill" show the same values

        // Buy transaction: total cost (securities + fees)
        let buySecuritiesValue = trade.buyOrder.price * Double(trade.buyOrder.quantity)
        let buyFees = FeeCalculationService.calculateTotalFees(for: buySecuritiesValue)
        let buyTotalCost = buySecuritiesValue + buyFees

        // Sell transaction: net proceeds (securities - fees)
        let sellSecuritiesValue = sellOrders.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
        let sellFees = sellOrders.reduce(0) { total, order in
            let orderAmount = order.price * Double(order.quantity)
            return total + FeeCalculationService.calculateTotalFees(for: orderAmount)
        }
        let sellNetProceeds = sellSecuritiesValue - sellFees

        // Gross profit = net proceeds - total cost
        return sellNetProceeds - buyTotalCost
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
        let fullTradeProfit = calculateTaxableProfit(
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
