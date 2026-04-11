import Foundation

struct Investment: Identifiable, Codable, Sendable {
    let id: String
    let batchId: String? // Optional: groups investments created together
    let investorId: String
    let investorName: String // Investor's username for display in trader views
    let traderId: String
    let traderName: String
    let amount: Double // Capital allocated to this investment (pool)
    let currentValue: Double // Current value including profit
    let date: Date
    let status: InvestmentStatus
    let performance: Double // Return percentage
    let numberOfTrades: Int
    let sequenceNumber: Int? // Optional: sequence number within batch (for display, e.g., "Investment #1")
    let createdAt: Date
    let updatedAt: Date
    let completedAt: Date?
    let specialization: String
    // Investment reservation status tracking
    var reservationStatus: InvestmentReservationStatus // Status of this individual investment

    // Computed properties
    var investedAmount: Double {
        amount
    }

    var isActive: Bool {
        status == .active
    }

    var isCompleted: Bool {
        status == .completed
    }

    /// Checks if this investment is completed
    var isInvestmentCompleted: Bool {
        reservationStatus == .completed
    }

    /// Checks if this investment is active
    var isInvestmentActive: Bool {
        reservationStatus == .active || reservationStatus == .executing || reservationStatus == .closed
    }

    /// Trash/delete allowed only while reserved (not yet committed to an ongoing trade path).
    /// App service charge for the batch is never refunded when deleting a split.
    var canBeDeleted: Bool {
        reservationStatus == .reserved
    }

    /// Creates a new Investment with updated status and completedAt date
    /// Optionally updates currentValue and performance if provided
    func markAsCompleted(
        calculatedProfit: Double? = nil,
        calculatedReturn: Double? = nil
    ) -> Investment {
        // Calculate profit and return if not provided
        let profit: Double
        let returnPercentage: Double

        if let calculatedProfit = calculatedProfit, let calculatedReturn = calculatedReturn {
            // Use provided values
            profit = calculatedProfit
            // calculatedReturn is already a percentage (e.g., 98.10) from calculateReturnPercentage()
            // No need to multiply by 100 again
            returnPercentage = calculatedReturn
        } else {
            // Fallback: use a reasonable return rate
            let baseReturnRate = 0.05 // 5% base return (as decimal)
            returnPercentage = baseReturnRate * 100 // Convert to percentage for storage
            profit = amount * baseReturnRate
        }

        // Calculate new current value (original amount + profit)
        let newCurrentValue = amount + profit

        return Investment(
            id: id,
            batchId: batchId,
            investorId: investorId,
            investorName: investorName,
            traderId: traderId,
            traderName: traderName,
            amount: amount,
            currentValue: newCurrentValue,
            date: date,
            status: .completed,
            performance: returnPercentage, // Already a percentage value (e.g., 98.10)
            numberOfTrades: numberOfTrades,
            sequenceNumber: sequenceNumber,
            createdAt: createdAt,
            updatedAt: Date(),
            completedAt: Date(),
            specialization: specialization,
            reservationStatus: .completed
        )
    }

    /// Creates a new Investment marked as cancelled (no profit/return)
    func markAsCancelled() -> Investment {
        return Investment(
            id: id,
            batchId: batchId,
            investorId: investorId,
            investorName: investorName,
            traderId: traderId,
            traderName: traderName,
            amount: amount,
            currentValue: amount, // no profit impact
            date: date,
            status: .cancelled,
            performance: 0.0, // will be displayed as '---'
            numberOfTrades: numberOfTrades,
            sequenceNumber: sequenceNumber,
            createdAt: createdAt,
            updatedAt: Date(),
            completedAt: Date(),
            specialization: specialization,
            reservationStatus: .cancelled
        )
    }

    /// Marks this investment as active
    func markInvestmentAsActive() -> Investment {
        return Investment(
            id: id,
            batchId: batchId,
            investorId: investorId,
            investorName: investorName,
            traderId: traderId,
            traderName: traderName,
            amount: amount,
            currentValue: currentValue,
            date: date,
            status: status,
            performance: performance,
            numberOfTrades: numberOfTrades,
            sequenceNumber: sequenceNumber,
            createdAt: createdAt,
            updatedAt: Date(),
            completedAt: completedAt,
            specialization: specialization,
            reservationStatus: .active
        )
    }

    /// Marks this investment as completed
    func markInvestmentAsCompleted() -> Investment {
        return Investment(
            id: id,
            batchId: batchId,
            investorId: investorId,
            investorName: investorName,
            traderId: traderId,
            traderName: traderName,
            amount: amount,
            currentValue: currentValue,
            date: date,
            status: status,
            performance: performance,
            numberOfTrades: numberOfTrades,
            sequenceNumber: sequenceNumber,
            createdAt: createdAt,
            updatedAt: Date(),
            completedAt: completedAt,
            specialization: specialization,
            reservationStatus: .completed
        )
    }

    // MARK: - Static Methods

    static func validateInvestment(
        investor: User,
        trader: MockTrader,
        amountPerInvestment: Double,
        numberOfInvestments: Int
    ) -> InvestmentValidationError? {
        // 1. Prevent traders from investing in other traders
        if investor.role == .trader {
            return .traderCannotInvestInTrader
        }

        // 2. Validate amount
        if amountPerInvestment <= 0 {
            return .invalidAmount
        }

        // 3. Validate number of investments
        if numberOfInvestments <= 0 {
            return .invalidNumberOfInvestments
        }

        // 4. Validate total amount
        let totalAmount = amountPerInvestment * Double(numberOfInvestments)
        if totalAmount < 100 {
            return .minimumAmountNotMet
        }

        return nil
    }

    /// Creates a single investment - each investment is a first-class entity
    static func createInvestment(
        investor: User,
        trader: MockTrader,
        amount: Double,
        batchId: String?,
        sequenceNumber: Int?,
        specialization: String
    ) throws -> Investment {
        // Validate the investment
        if let error = validateInvestment(
            investor: investor,
            trader: trader,
            amountPerInvestment: amount,
            numberOfInvestments: 1 // Each investment is a single investment
        ) {
            throw error
        }

        return Investment(
            id: UUID().uuidString,
            batchId: batchId,
            investorId: investor.id,
            investorName: investor.username,
            traderId: trader.id.uuidString,
            traderName: trader.name,
            amount: amount,
            currentValue: amount,
            date: Date(),
            status: .active,
            performance: 0.0,
            numberOfTrades: 0,
            sequenceNumber: sequenceNumber,
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: nil,
            specialization: specialization,
            reservationStatus: .reserved
        )
    }

    /// Creates multiple investments from a batch
    static func createInvestmentsFromBatch(
        investor: User,
        trader: MockTrader,
        batchId: String,
        amountPerInvestment: Double,
        numberOfInvestments: Int,
        specialization: String
    ) throws -> [Investment] {
        // Validate the batch
        if let error = validateInvestment(
            investor: investor,
            trader: trader,
            amountPerInvestment: amountPerInvestment,
            numberOfInvestments: numberOfInvestments
        ) {
            throw error
        }

        // Create one investment per requested amount
        var investments: [Investment] = []
        for sequenceNumber in 1...numberOfInvestments {
            let investment = try createInvestment(
                investor: investor,
                trader: trader,
                amount: amountPerInvestment,
                batchId: batchId,
                sequenceNumber: sequenceNumber,
                specialization: specialization
            )
            investments.append(investment)
        }

        return investments
    }
}
