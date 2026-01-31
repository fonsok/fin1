import Foundation

enum InvestmentStatus: String, CaseIterable, Codable {
    case submitted
    case active
    case completed
    case cancelled

    var displayName: String {
        switch self {
        case .submitted: return "Submitted"
        case .active: return "Active"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var color: String {
        switch self {
        case .submitted: return "fin1AccentOrange"
        case .active: return "fin1AccentGreen"
        case .completed: return "fin1AccentLightBlue"
        case .cancelled: return "fin1AccentRed"
        }
    }
}

/// Time period options for filtering completed investments
enum InvestmentTimePeriod: CaseIterable {
    case last7Days
    case last30Days
    case last90Days
    case lastYear
    case allTime

    var displayName: String {
        switch self {
        case .last7Days: return "Letzte 7 Tage"
        case .last30Days: return "Letzte 30 Tage"
        case .last90Days: return "Letzte 90 Tage"
        case .lastYear: return "Letztes Jahr"
        case .allTime: return "Alle"
        }
    }

    /// Returns the cutoff date for this time period
    func cutoffDate() -> Date {
        let calendar = Calendar.current
        switch self {
        case .last7Days:
            return calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .last30Days:
            return calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        case .last90Days:
            return calendar.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        case .lastYear:
            return calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        case .allTime:
            return calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date()
        }
    }
}

struct Investment: Identifiable, Codable {
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

    /// Checks if this investment can be deleted (only if reserved)
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
struct InvestmentPool: Identifiable, Codable {
    let id: String
    let traderId: String
    let poolNumber: Int
    let status: InvestmentStatus
    let currentBalance: Double
    let totalInvested: Double
    let numberOfInvestors: Int
    let createdAt: Date
    let updatedAt: Date
    let completedAt: Date?

    var averageInvestment: Double {
        numberOfInvestors > 0 ? totalInvested / Double(numberOfInvestors) : 0
    }
}

// MARK: - Supporting Enums and Structs

enum InvestmentSelectionStrategy: String, CaseIterable, Codable {
    case multipleInvestments

    var displayName: String {
        switch self {
        case .multipleInvestments: return "Multiple Investments"
        }
    }

    var description: String {
        switch self {
        case .multipleInvestments: return "Invest across multiple future investments"
        }
    }
}

enum InvestmentReservationStatus: String, CaseIterable, Codable {
    case reserved
    case active
    case closed
    case executing
    case completed
    case cancelled

    var displayName: String {
        switch self {
        case .reserved: return "Reserved"
        case .active: return "Active"
        case .closed: return "Closed"
        case .executing: return "Executing"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}

enum PoolStatus: String, CaseIterable, Codable {
    case active
    case closed
    case executing
    case completed
    case cancelled

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .closed: return "Closed"
        case .executing: return "Executing"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}

enum InvestmentValidationError: Error, LocalizedError {
    case traderCannotInvestInTrader
    case invalidAmount
    case invalidNumberOfInvestments
    case minimumAmountNotMet
    case investmentNotAvailable
    case insufficientFunds

    var errorDescription: String? {
        switch self {
        case .traderCannotInvestInTrader:
            return "Traders cannot invest in other traders"
        case .invalidAmount:
            return "Invalid investment amount"
        case .invalidNumberOfInvestments:
            return "Invalid number of investments"
        case .minimumAmountNotMet:
            return "Minimum investment amount not met"
        case .investmentNotAvailable:
            return "Investment is not available"
        case .insufficientFunds:
            return "Insufficient funds"
        }
    }
}

struct InvestmentReservation: Identifiable, Codable {
    let id: String
    let sequenceNumber: Int // Sequence number within batch (for display)
    let status: InvestmentReservationStatus
    let actualInvestmentId: String? // Legacy: kept for backward compatibility
    let allocatedAmount: Double
    let reservedAt: Date
    let isLocked: Bool
}

struct InvestmentAllocation: Identifiable, Codable {
    let id: String
    let investmentId: String
    let poolId: String // InvestmentPool ID (kept for trader dashboard compatibility)
    let allocatedAmount: Double
    let createdAt: Date
}
