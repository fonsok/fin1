import Foundation

// MARK: - MockTrader bridge (seed data + legacy trader module)

extension InvestorTrader {
    init(mock: MockTrader, isFromMockCatalog: Bool = true) {
        self.catalogId = mock.id.uuidString
        self.parseUserId = mock.parseUserId
        self.name = mock.name
        self.username = mock.username
        self.specialization = mock.specialization
        self.experienceYears = mock.experienceYears
        self.isVerified = mock.isVerified
        self.riskLevel = mock.riskLevel
        self.isFromMockCatalog = isFromMockCatalog
        self.demoMetrics = TraderDemoMetrics(
            performance: mock.performance,
            totalTrades: mock.totalTrades,
            winRate: mock.winRate,
            averageReturn: mock.averageReturn,
            totalReturn: mock.totalReturn,
            recentTrades: mock.recentTrades,
            lastNTrades: mock.lastNTrades,
            successfulTradesInLastN: mock.successfulTradesInLastN,
            averageReturnLastNTrades: mock.averageReturnLastNTrades,
            consecutiveWinningTrades: mock.consecutiveWinningTrades,
            maxDrawdown: mock.maxDrawdown,
            sharpeRatio: mock.sharpeRatio
        )
    }
}

extension TraderDemoMetrics {
    init(mock: MockTrader) {
        self.init(
            performance: mock.performance,
            totalTrades: mock.totalTrades,
            winRate: mock.winRate,
            averageReturn: mock.averageReturn,
            totalReturn: mock.totalReturn,
            recentTrades: mock.recentTrades,
            lastNTrades: mock.lastNTrades,
            successfulTradesInLastN: mock.successfulTradesInLastN,
            averageReturnLastNTrades: mock.averageReturnLastNTrades,
            consecutiveWinningTrades: mock.consecutiveWinningTrades,
            maxDrawdown: mock.maxDrawdown,
            sharpeRatio: mock.sharpeRatio
        )
    }
}
