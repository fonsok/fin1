import Foundation

// MARK: - Transaction Limit Model
/// Represents transaction limits for a user based on risk class and regulatory requirements
struct TransactionLimit: Codable, Identifiable {
    let id: String
    let userId: String
    let dailyLimit: Double
    let weeklyLimit: Double
    let monthlyLimit: Double
    let riskClassBasedLimit: Double
    let dailySpent: Double
    let weeklySpent: Double
    let monthlySpent: Double
    let lastUpdated: Date
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        dailyLimit: Double,
        weeklyLimit: Double,
        monthlyLimit: Double,
        riskClassBasedLimit: Double,
        dailySpent: Double = 0.0,
        weeklySpent: Double = 0.0,
        monthlySpent: Double = 0.0,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.dailyLimit = dailyLimit
        self.weeklyLimit = weeklyLimit
        self.monthlyLimit = monthlyLimit
        self.riskClassBasedLimit = riskClassBasedLimit
        self.dailySpent = dailySpent
        self.weeklySpent = weeklySpent
        self.monthlySpent = monthlySpent
        self.lastUpdated = lastUpdated
    }
    
    // MARK: - Computed Properties
    
    var remainingDailyLimit: Double {
        max(0, self.dailyLimit - self.dailySpent)
    }
    
    var remainingWeeklyLimit: Double {
        max(0, self.weeklyLimit - self.weeklySpent)
    }
    
    var remainingMonthlyLimit: Double {
        max(0, self.monthlyLimit - self.monthlySpent)
    }
    
    var effectiveDailyLimit: Double {
        min(self.dailyLimit, self.riskClassBasedLimit)
    }
    
    var effectiveWeeklyLimit: Double {
        min(self.weeklyLimit, self.riskClassBasedLimit * 7)
    }
    
    var effectiveMonthlyLimit: Double {
        min(self.monthlyLimit, self.riskClassBasedLimit * 30)
    }
    
    func canSpend(amount: Double) -> TransactionLimitCheckResult {
        let effectiveDaily = self.effectiveDailyLimit
        let effectiveWeekly = self.effectiveWeeklyLimit
        let effectiveMonthly = self.effectiveMonthlyLimit
        
        let newDailySpent = self.dailySpent + amount
        let newWeeklySpent = self.weeklySpent + amount
        let newMonthlySpent = self.monthlySpent + amount
        
        var violations: [TransactionLimitViolation] = []
        
        if newDailySpent > effectiveDaily {
            violations.append(.dailyLimitExceeded(
                limit: effectiveDaily,
                current: self.dailySpent,
                requested: amount,
                remaining: self.remainingDailyLimit
            ))
        }
        
        if newWeeklySpent > effectiveWeekly {
            violations.append(.weeklyLimitExceeded(
                limit: effectiveWeekly,
                current: self.weeklySpent,
                requested: amount,
                remaining: self.remainingWeeklyLimit
            ))
        }
        
        if newMonthlySpent > effectiveMonthly {
            violations.append(.monthlyLimitExceeded(
                limit: effectiveMonthly,
                current: self.monthlySpent,
                requested: amount,
                remaining: self.remainingMonthlyLimit
            ))
        }
        
        return TransactionLimitCheckResult(
            isAllowed: violations.isEmpty,
            violations: violations,
            remainingDaily: self.remainingDailyLimit,
            remainingWeekly: self.remainingWeeklyLimit,
            remainingMonthly: self.remainingMonthlyLimit
        )
    }
}

// MARK: - Transaction Limit Check Result

struct TransactionLimitCheckResult {
    let isAllowed: Bool
    let violations: [TransactionLimitViolation]
    let remainingDaily: Double
    let remainingWeekly: Double
    let remainingMonthly: Double
    
    var errorMessage: String? {
        guard !self.violations.isEmpty else { return nil }
        return self.violations.map { $0.message }.joined(separator: "\n")
    }
}

// MARK: - Transaction Limit Violation

enum TransactionLimitViolation {
    case dailyLimitExceeded(limit: Double, current: Double, requested: Double, remaining: Double)
    case weeklyLimitExceeded(limit: Double, current: Double, requested: Double, remaining: Double)
    case monthlyLimitExceeded(limit: Double, current: Double, requested: Double, remaining: Double)
    
    var message: String {
        switch self {
        case .dailyLimitExceeded(let limit, let current, let requested, let remaining):
            return "Tägliches Limit überschritten. Limit: €\(limit.formatted(.number.precision(.fractionLength(2)))), bereits ausgegeben: €\(current.formatted(.number.precision(.fractionLength(2)))), angefragt: €\(requested.formatted(.number.precision(.fractionLength(2)))), verbleibend: €\(remaining.formatted(.number.precision(.fractionLength(2)))))"
        case .weeklyLimitExceeded(let limit, let current, let requested, let remaining):
            return "Wöchentliches Limit überschritten. Limit: €\(limit.formatted(.number.precision(.fractionLength(2)))), bereits ausgegeben: €\(current.formatted(.number.precision(.fractionLength(2)))), angefragt: €\(requested.formatted(.number.precision(.fractionLength(2)))), verbleibend: €\(remaining.formatted(.number.precision(.fractionLength(2)))))"
        case .monthlyLimitExceeded(let limit, let current, let requested, let remaining):
            return "Monatliches Limit überschritten. Limit: €\(limit.formatted(.number.precision(.fractionLength(2)))), bereits ausgegeben: €\(current.formatted(.number.precision(.fractionLength(2)))), angefragt: €\(requested.formatted(.number.precision(.fractionLength(2)))), verbleibend: €\(remaining.formatted(.number.precision(.fractionLength(2)))))"
        }
    }
}
