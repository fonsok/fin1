import Foundation

// MARK: - Commission Deduction Details

/// Details for commission deduction transaction display
struct CommissionDeductionDetails {
    let investmentSequenceNumber: Int?
    let traderName: String?
    let tradeNumbers: [String]
    let grossProfit: Double
    let commissionRate: Double

    init(
        investmentSequenceNumber: Int? = nil,
        traderName: String? = nil,
        tradeNumbers: [String] = [],
        grossProfit: Double = 0,
        commissionRate: Double = CalculationConstants.FeeRates.traderCommissionRate
    ) {
        self.investmentSequenceNumber = investmentSequenceNumber
        self.traderName = traderName
        self.tradeNumbers = tradeNumbers
        self.grossProfit = grossProfit
        self.commissionRate = commissionRate
    }
}

// MARK: - Investor Cash Balance Service Protocol

/// Protocol for managing investor cash balances
protocol InvestorCashBalanceServiceProtocol: ServiceLifecycle {
    /// Gets the current cash balance for an investor
    /// - Parameter investorId: The investor's user ID
    /// - Returns: Current cash balance in EUR
    func getBalance(for investorId: String) -> Double

    /// Gets formatted balance string for an investor
    /// - Parameter investorId: The investor's user ID
    /// - Returns: Formatted balance string (e.g., "€25,000.00")
    func getFormattedBalance(for investorId: String) -> String

    /// Processes an investment (deducts amount from investor balance)
    /// - Parameters:
    ///   - investorId: The investor's user ID
    ///   - amount: Investment amount to deduct
    ///   - investmentId: The investment ID for accounting linkage
    func processInvestment(investorId: String, amount: Double, investmentId: String) async

    /// Processes app service charge deduction (separate accounting transaction)
    /// - Note: App service charge is ONLY charged to investors (not traders).
    ///   It is NON-REFUNDABLE and is charged when investment is created.
    ///   It is NOT refunded if investment is cancelled or deleted.
    /// - Parameters:
    ///   - investorId: The investor's user ID (service charge applies only to investors)
    ///   - chargeAmount: App service charge amount to deduct
    ///   - investmentId: The investment ID for accounting linkage (links charge to investment)
    ///   - metadata: Additional accounting metadata (contra account posting IDs, VAT split, etc.)
    func processAppServiceCharge(
        investorId: String,
        chargeAmount: Double,
        investmentId: String,
        metadata: [String: String]
    ) async

    /// Backward compatible alias (legacy naming).
    func processPlatformServiceCharge(
        investorId: String,
        chargeAmount: Double,
        investmentId: String,
        metadata: [String: String]
    ) async

    /// Processes profit distribution from a completed pool trade (adds to investor balance)
    /// - Parameters:
    ///   - investorId: The investor's user ID
    ///   - profitAmount: Profit amount to add
    ///   - investmentId: Optional investment ID to link this profit distribution to a specific investment
    func processProfitDistribution(investorId: String, profitAmount: Double, investmentId: String?) async

    /// Processes profit distribution with calculation breakdown (for investment completion)
    /// Stores principal return and gross profit in metadata for display purposes
    /// - Parameters:
    ///   - investorId: The investor's user ID
    ///   - profitAmount: Total profit amount (principal return + gross profit)
    ///   - principalReturn: Principal return amount
    ///   - grossProfit: Gross profit amount
    ///   - investmentId: Optional investment ID to link this profit distribution to a specific investment
    func processProfitDistributionWithBreakdown(
        investorId: String,
        profitAmount: Double,
        principalReturn: Double,
        grossProfit: Double,
        investmentId: String?
    ) async

    /// Processes commission deduction from investor's cash balance
    /// Records commission as a separate debit transaction for proper accounting transparency
    /// - Parameters:
    ///   - investorId: The investor's user ID
    ///   - commissionAmount: Commission amount to deduct
    ///   - investmentId: Optional investment ID to link this commission to a specific investment
    ///   - details: Optional additional details for accounting display (investment sequence, trade numbers, gross profit, rate)
    func processCommissionDeduction(
        investorId: String,
        commissionAmount: Double,
        investmentId: String?,
        details: CommissionDeductionDetails?
    ) async

    /// Convenience method without details parameter (backward compatibility)
    func processCommissionDeduction(investorId: String, commissionAmount: Double, investmentId: String?) async

    /// Processes remaining balance distribution (adds to investor balance)
    /// - Parameters:
    ///   - investorId: The investor's user ID
    ///   - amount: Amount to add
    ///   - investmentId: Optional investment ID associated with this distribution
    func processRemainingBalanceDistribution(investorId: String, amount: Double, investmentId: String?) async

    /// Processes a deposit (adds amount to investor balance)
    /// - Parameters:
    ///   - investorId: The investor's user ID
    ///   - amount: Deposit amount to add
    func processDeposit(investorId: String, amount: Double) async

    /// Processes a withdrawal (deducts amount from investor balance)
    /// - Parameters:
    ///   - investorId: The investor's user ID
    ///   - amount: Withdrawal amount to deduct
    func processWithdrawal(investorId: String, amount: Double) async

    /// Checks if investor has sufficient funds for an investment
    /// - Parameters:
    ///   - investorId: The investor's user ID
    ///   - amount: Investment amount to check
    /// - Returns: True if investor has sufficient funds
    func hasSufficientFunds(investorId: String, for amount: Double) -> Bool

    /// Calculates estimated balance after an investment
    /// - Parameters:
    ///   - investorId: The investor's user ID
    ///   - amount: Investment amount
    /// - Returns: Estimated balance after investment
    func estimatedBalanceAfterInvestment(investorId: String, amount: Double) -> Double

    /// Resets investor balance to initial amount
    /// - Parameter investorId: The investor's user ID
    func resetBalance(for investorId: String) async

    func getTransactions(for investorId: String) -> [AccountStatementEntry]
}
