import Foundation

// MARK: - Investor Collection Bill Calculation DTOs

/// Input data for collection bill calculation
/// Contains all necessary data from Investment, Trade, Invoice, and Participation models
struct InvestorCollectionBillInput {
    /// Investment capital amount (source of truth for buy amount)
    let investmentCapital: Double

    /// Trade entry price (source of truth for buy price)
    let buyPrice: Double

    /// Trade total quantity (reference for sell percentage calculation)
    let tradeTotalQuantity: Double

    /// Investor's ownership percentage (0.0 to 1.0)
    let ownershipPercentage: Double

    /// Buy invoice (optional, used for fee calculation)
    let buyInvoice: Invoice?

    /// Sell invoices (used for sell price and fee calculation)
    let sellInvoices: [Invoice]

    /// Investor's allocated amount (for ROI calculation reference)
    let investorAllocatedAmount: Double
}

/// Output data from collection bill calculation
/// Contains all calculated values for display in collection bill
struct InvestorCollectionBillOutput {
    // Buy leg
    let buyAmount: Double
    let buyQuantity: Double
    let buyPrice: Double
    let buyFees: Double
    let buyFeeDetails: [InvestorFeeDetail]

    // Residual amount (leftover after rounding quantity to whole number)
    // This occurs when rounding down to whole units leaves unused capital
    // Should be returned to investor's cash balance via processRemainingBalanceDistribution
    let residualAmount: Double

    // Sell leg
    let sellAmount: Double
    let sellQuantity: Double
    let sellAveragePrice: Double
    let sellFees: Double
    let sellFeeDetails: [InvestorFeeDetail]

    // Profit calculations
    let grossProfit: Double
    let roiGrossProfit: Double
    let roiInvestedAmount: Double

    /// True when a backend fetch was attempted, failed, and local calculation was used instead.
    let usedLocalFallbackDueToBackendError: Bool
}

/// Validation result for input data
enum ValidationResult {
    case valid
    case warning(String)
    case error(String)

    var isValid: Bool {
        switch self {
        case .valid, .warning:
            return true
        case .error:
            return false
        }
    }

    var errorMessage: String? {
        switch self {
        case .error(let message):
            return message
        default:
            return nil
        }
    }

    var warningMessage: String? {
        switch self {
        case .warning(let message):
            return message
        default:
            return nil
        }
    }
}
