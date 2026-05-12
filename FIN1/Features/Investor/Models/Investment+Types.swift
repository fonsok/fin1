import Foundation

// MARK: - Investment Status & Time Period

enum InvestmentStatus: String, CaseIterable, Codable, Sendable {
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
enum InvestmentTimePeriod: CaseIterable, Sendable {
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

// MARK: - Pool & Reservation

struct InvestmentPool: Identifiable, Codable, Sendable {
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

enum InvestmentSelectionStrategy: String, CaseIterable, Codable, Sendable {
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

enum InvestmentReservationStatus: String, CaseIterable, Codable, Sendable {
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

enum PoolStatus: String, CaseIterable, Codable, Sendable {
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

// MARK: - Validation & DTOs

enum InvestmentValidationError: Error, LocalizedError, Sendable {
    case traderCannotInvestInTrader
    case invalidAmount
    case invalidNumberOfInvestments
    case minimumAmountNotMet
    case maximumAmountExceeded
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
        case .maximumAmountExceeded:
            return "Maximum investment amount per slot exceeded"
        case .investmentNotAvailable:
            return "Investment is not available"
        case .insufficientFunds:
            return "Insufficient funds"
        }
    }
}

struct InvestmentReservation: Identifiable, Codable, Sendable {
    let id: String
    let sequenceNumber: Int
    let status: InvestmentReservationStatus
    let actualInvestmentId: String?
    let allocatedAmount: Double
    let reservedAt: Date
    let isLocked: Bool
}

struct InvestmentAllocation: Identifiable, Codable, Sendable {
    let id: String
    let investmentId: String
    let poolId: String
    let allocatedAmount: Double
    let createdAt: Date
}
