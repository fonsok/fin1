import Foundation

// MARK: - Demo performance (Dashboard / filters only — not SSOT for production traders)

struct TraderDemoMetrics: Sendable {
    let performance: Double
    let totalTrades: Int
    let winRate: Double
    let averageReturn: Double
    let totalReturn: Double
    let recentTrades: [MockTradePerformance]
    let lastNTrades: Int
    let successfulTradesInLastN: Int
    let averageReturnLastNTrades: Double
    let consecutiveWinningTrades: Int
    let maxDrawdown: Double
    let sharpeRatio: Double
}

// MARK: - Investor-facing trader (Parse catalog + optional demo overlay)

/// Production trader row for investor UI. Server identity is SSOT; `demoMetrics` only for mock-seed dashboard/discover filters.
struct InvestorTrader: Identifiable, Sendable {
    /// Stable list key (`MockTrader.id` or Parse `objectId` for server-only rows).
    let catalogId: String
    let parseUserId: String?
    let name: String
    let username: String
    let specialization: String
    let experienceYears: Int
    let isVerified: Bool
    let riskLevel: TraderRiskLevel
    /// Non-nil only for mock-seed catalog rows (Top Recent Trades, advanced filters).
    let demoMetrics: TraderDemoMetrics?
    let isFromMockCatalog: Bool

    var id: String { self.catalogId }
}
