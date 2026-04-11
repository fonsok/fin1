import Foundation

// MARK: - Investment Batch Model
/// Represents a batch of investments created together
struct InvestmentBatch: Identifiable, Codable {
    let id: String
    let investorId: String
    let traderId: String
    let traderName: String
    let totalAmount: Double
    let appServiceCharge: Double
    let specialization: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case investorId
        case traderId
        case traderName
        case totalAmount
        case appServiceCharge
        case platformServiceCharge // legacy decode support
        case specialization
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        investorId = try c.decode(String.self, forKey: .investorId)
        traderId = try c.decode(String.self, forKey: .traderId)
        traderName = try c.decode(String.self, forKey: .traderName)
        totalAmount = try c.decode(Double.self, forKey: .totalAmount)
        appServiceCharge =
            try c.decodeIfPresent(Double.self, forKey: .appServiceCharge)
            ?? c.decode(Double.self, forKey: .platformServiceCharge)
        specialization = try c.decode(String.self, forKey: .specialization)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(investorId, forKey: .investorId)
        try c.encode(traderId, forKey: .traderId)
        try c.encode(traderName, forKey: .traderName)
        try c.encode(totalAmount, forKey: .totalAmount)
        try c.encode(appServiceCharge, forKey: .appServiceCharge)
        try c.encode(specialization, forKey: .specialization)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
    }

    /// Creates a new investment batch
    static func createBatch(
        investor: User,
        trader: MockTrader,
        totalAmount: Double,
        appServiceCharge: Double,
        specialization: String
    ) -> InvestmentBatch {
        let now = Date()
        return InvestmentBatch(
            id: UUID().uuidString,
            investorId: investor.id,
            traderId: trader.id.uuidString,
            traderName: trader.name,
            specialization: specialization,
            totalAmount: totalAmount,
            appServiceCharge: appServiceCharge,
            createdAt: now,
            updatedAt: now
        )
    }

    /// Initializer for creating InvestmentBatch from existing data
    init(
        id: String,
        investorId: String,
        traderId: String,
        traderName: String,
        specialization: String,
        totalAmount: Double,
        appServiceCharge: Double,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.investorId = investorId
        self.traderId = traderId
        self.traderName = traderName
        self.specialization = specialization
        self.totalAmount = totalAmount
        self.appServiceCharge = appServiceCharge
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
