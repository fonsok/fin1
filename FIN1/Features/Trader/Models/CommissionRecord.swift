import Foundation

// MARK: - Commission Record Model

/// Represents a commission payment record for accounting and tracking
struct CommissionRecord: Identifiable, Codable {
    let id: String
    let tradeId: String
    let traderId: String
    let investmentId: String?
    let grossProfit: Double
    let commissionRate: Double
    let commissionAmount: Double
    let netProfit: Double
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        tradeId: String,
        traderId: String,
        investmentId: String? = nil,
        grossProfit: Double,
        commissionRate: Double,
        commissionAmount: Double,
        netProfit: Double,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.tradeId = tradeId
        self.traderId = traderId
        self.investmentId = investmentId
        self.grossProfit = grossProfit
        self.commissionRate = commissionRate
        self.commissionAmount = commissionAmount
        self.netProfit = netProfit
        self.createdAt = createdAt
    }
}
