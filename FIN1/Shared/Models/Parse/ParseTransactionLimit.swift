import Foundation

// MARK: - Parse Transaction Limit Model
/// Parse Server model for persisting transaction limits
struct ParseTransactionLimit: Codable {
    let objectId: String?
    let userId: String
    let dailyLimit: Double
    let weeklyLimit: Double
    let monthlyLimit: Double
    let riskClassBasedLimit: Double
    let dailySpent: Double
    let weeklySpent: Double
    let monthlySpent: Double
    let lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case objectId
        case userId
        case dailyLimit
        case weeklyLimit
        case monthlyLimit
        case riskClassBasedLimit
        case dailySpent
        case weeklySpent
        case monthlySpent
        case lastUpdated
    }
    
    init(
        objectId: String? = nil,
        userId: String,
        dailyLimit: Double,
        weeklyLimit: Double,
        monthlyLimit: Double,
        riskClassBasedLimit: Double,
        dailySpent: Double = 0,
        weeklySpent: Double = 0,
        monthlySpent: Double = 0,
        lastUpdated: Date = Date()
    ) {
        self.objectId = objectId
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
    
    func toTransactionLimit(riskClass: RiskClass) -> TransactionLimit {
        TransactionLimit(
            userId: userId,
            dailyLimit: dailyLimit,
            weeklyLimit: weeklyLimit,
            monthlyLimit: monthlyLimit,
            riskClassBasedLimit: riskClassBasedLimit,
            dailySpent: dailySpent,
            weeklySpent: weeklySpent,
            monthlySpent: monthlySpent,
            riskClass: riskClass
        )
    }
}

// MARK: - Parse Transaction History Model
/// Parse Server model for persisting transaction history (for limit tracking)
struct ParseTransactionHistory: Codable {
    let objectId: String?
    let userId: String
    let date: Date
    let amount: Double
    let transactionType: String // "deposit", "withdrawal", "trade", etc.
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case objectId
        case userId
        case date
        case amount
        case transactionType
        case createdAt
    }
    
    init(
        objectId: String? = nil,
        userId: String,
        date: Date,
        amount: Double,
        transactionType: String,
        createdAt: Date? = nil
    ) {
        self.objectId = objectId
        self.userId = userId
        self.date = date
        self.amount = amount
        self.transactionType = transactionType
        self.createdAt = createdAt
    }
}
