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

    // Canonical ledger totals (single source for UI — always consistent with grossProfit)
    let totalBuyCost: Double
    let netSellAmount: Double

    // Profit calculations
    let grossProfit: Double
    let roiGrossProfit: Double
    let roiInvestedAmount: Double

    /// Booked commission on the server Beleg (`metadata.commission`); nil for local-only rows.
    let bookedCommission: Double?
    /// Booked net profit on the server Beleg (`metadata.netProfit`).
    let bookedNetProfit: Double?
    /// Booked payout (`metadata.transferAmount` = netSellAmount − commission); nil for local-only rows.
    let bookedTransferAmount: Double?

    /// GoB: `accountingDocumentNumber` of the archived collection bill when loaded from server.
    let accountingDocumentNumber: String?
    /// Non-nil when leg detail and booked summary on the same Beleg diverge.
    let belegInconsistencyMessage: String?

    /// Where the amounts originated.
    let dataSource: InvestorCollectionBillDataSource

    /// True when a backend fetch was attempted, failed, and local calculation was used instead.
    var usedLocalFallbackDueToBackendError: Bool {
        self.dataSource == .localFallbackAfterBackendError
    }

    var isFromArchivedBeleg: Bool {
        switch self.dataSource {
        case .backendBeleg, .backendBelegInconsistent:
            return true
        case .localInvoices, .localFallbackAfterBackendError:
            return false
        }
    }
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
