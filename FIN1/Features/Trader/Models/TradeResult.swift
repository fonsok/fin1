import Foundation

// MARK: - Trade Result

struct TradeResult: Identifiable, Codable, Sendable {
    let id: String
    let tradeId: String
    let traderId: String
    let profitLoss: Double
    let fees: Double
    let taxes: Double
    let performanceFee: Double
    let netProfitLoss: Double
    let createdAt: Date

    var isProfitable: Bool {
        self.netProfitLoss > 0
    }
}
