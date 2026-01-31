import Foundation

// MARK: - Investment Batch Model
/// Represents a batch of investments created together
struct InvestmentBatch: Identifiable, Codable {
    let id: String
    let investorId: String
    let traderId: String
    let traderName: String
    let totalAmount: Double
    let platformServiceCharge: Double
    let specialization: String
    let createdAt: Date
    let updatedAt: Date

    /// Creates a new investment batch
    static func createBatch(
        investor: User,
        trader: MockTrader,
        totalAmount: Double,
        platformServiceCharge: Double,
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
            platformServiceCharge: platformServiceCharge,
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
        platformServiceCharge: Double,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.investorId = investorId
        self.traderId = traderId
        self.traderName = traderName
        self.specialization = specialization
        self.totalAmount = totalAmount
        self.platformServiceCharge = platformServiceCharge
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
