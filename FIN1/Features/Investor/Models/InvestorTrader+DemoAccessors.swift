import Foundation

// MARK: - Demo metric accessors (Dashboard / detail when demo overlay exists)

extension InvestorTrader {
    var performance: Double { self.demoMetrics?.performance ?? 0 }
    var totalTrades: Int { self.demoMetrics?.totalTrades ?? 0 }
    var winRate: Double { self.demoMetrics?.winRate ?? 0 }
    var averageReturn: Double { self.demoMetrics?.averageReturn ?? 0 }
    var totalReturn: Double { self.demoMetrics?.totalReturn ?? 0 }
    var recentTrades: [MockTradePerformance] { self.demoMetrics?.recentTrades ?? [] }
    var lastNTrades: Int { self.demoMetrics?.lastNTrades ?? 0 }
    var successfulTradesInLastN: Int { self.demoMetrics?.successfulTradesInLastN ?? 0 }
    var averageReturnLastNTrades: Double { self.demoMetrics?.averageReturnLastNTrades ?? 0 }
    var consecutiveWinningTrades: Int { self.demoMetrics?.consecutiveWinningTrades ?? 0 }
    var maxDrawdown: Double { self.demoMetrics?.maxDrawdown ?? 0 }
    var sharpeRatio: Double { self.demoMetrics?.sharpeRatio ?? 0 }
}
