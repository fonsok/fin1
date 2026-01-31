import Foundation

// MARK: - Advanced Filter Criteria (Legacy - keeping for compatibility)
struct TraderFilterCriteria {
    // Trade Count Options
    var selectedTradeCountOption: TradeCountOption = .last20

    // Basic Filters
    var minWinRate: Double?
    var minTotalTrades: Double?
    var minExperienceYears: Double?
    var maxRiskLevel: MockTrader.RiskLevel?
    var onlyVerified: Bool?

    // Advanced Financial Metrics
    var minReturnRate: Double?
    var minAverageReturnPerTrade: Double?
    var minReturnFactor: Double?

    // Risk Metrics
    var maxMaxDrawdown: Double?
    var minSharpeRatio: Double?

    static let defaultCriteria = TraderFilterCriteria(
        selectedTradeCountOption: .last20,
        minWinRate: nil,
        minTotalTrades: nil,
        minExperienceYears: nil,
        maxRiskLevel: nil,
        onlyVerified: nil,
        minReturnRate: nil,
        minAverageReturnPerTrade: nil,
        minReturnFactor: nil,
        maxMaxDrawdown: nil,
        minSharpeRatio: nil
    )
}







