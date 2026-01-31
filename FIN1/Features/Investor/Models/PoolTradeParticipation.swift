import Foundation

/// Tracks which investment pools participated in which trades
/// Used for calculating profit distribution to investors
struct PoolTradeParticipation: Identifiable, Codable {
    let id: String
    let tradeId: String
    let investmentId: String
    let poolReservationId: String // ID of the PoolReservation that participated
    let poolNumber: Int
    let allocatedAmount: Double // Amount from this pool used in the trade
    let totalTradeValue: Double // Total value of the trade (trader + all pools)
    let ownershipPercentage: Double // allocatedAmount / totalTradeValue
    let profitShare: Double? // Profit allocated to this pool (calculated when trade completes)
    let createdAt: Date
    let updatedAt: Date

    init(
        id: String = UUID().uuidString,
        tradeId: String,
        investmentId: String,
        poolReservationId: String,
        poolNumber: Int,
        allocatedAmount: Double,
        totalTradeValue: Double,
        ownershipPercentage: Double? = nil,
        profitShare: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.tradeId = tradeId
        self.investmentId = investmentId
        self.poolReservationId = poolReservationId
        self.poolNumber = poolNumber
        self.allocatedAmount = allocatedAmount
        self.totalTradeValue = totalTradeValue
        // Calculate ownership percentage if not provided
        self.ownershipPercentage = ownershipPercentage ?? (totalTradeValue > 0 ? allocatedAmount / totalTradeValue : 0.0)
        self.profitShare = profitShare
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Updates the profit share for this participation
    func withProfitShare(_ profitShare: Double) -> PoolTradeParticipation {
        return PoolTradeParticipation(
            id: id,
            tradeId: tradeId,
            investmentId: investmentId,
            poolReservationId: poolReservationId,
            poolNumber: poolNumber,
            allocatedAmount: allocatedAmount,
            totalTradeValue: totalTradeValue,
            ownershipPercentage: ownershipPercentage,
            profitShare: profitShare,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
}
