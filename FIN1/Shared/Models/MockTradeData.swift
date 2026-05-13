import Foundation
import SwiftUI

// MARK: - Mock Trade Performance
struct MockTradePerformance: Identifiable {
    let id = UUID()
    let date: Date
    let profitLoss: Double // Actual monetary profit/loss amount (preTaxProfit in currency, e.g., 100.50 EUR)
    let investmentCost: Double // Total buy cost (for ROI calculation)
    let isSuccessful: Bool
    let instrument: String
    let tradeType: String // "Buy" or "Sell"

    // Calculate ROI (Return on Investment) percentage
    // ROI = (profitLoss / investmentCost) * 100
    // Note: profitLoss is monetary amount, roi is percentage return
    var roi: Double {
        guard self.investmentCost > 0 else { return 0 }
        return (self.profitLoss / self.investmentCost) * 100
    }

    // Successful trade = ROI > 0
    var isSuccessfulByROI: Bool {
        return self.roi > 0
    }
}

// MARK: - Trade Count Options
enum TradeCountOption: String, CaseIterable, Codable {
    case last5 = "Last 5 Trades"
    case last10 = "Last 10 Trades"
    case last20 = "Last 20 Trades"
    case last30 = "Last 30 Trades"
    case allTrades = "All Trades"
    case last1Week = "Last 1 Week"
    case last2Weeks = "Last 2 Weeks"
    case last4Weeks = "Last 4 Weeks"
    case last8Weeks = "Last 8 Weeks"
    case last12Weeks = "Last 12 Weeks"

    var displayName: String { rawValue }

    var tradeCount: Int? {
        switch self {
        case .last5: return 5
        case .last10: return 10
        case .last20: return 20
        case .last30: return 30
        case .allTrades: return nil
        case .last1Week, .last2Weeks, .last4Weeks, .last8Weeks, .last12Weeks: return nil
        }
    }

    var weekCount: Int? {
        switch self {
        case .last1Week: return 1
        case .last2Weeks: return 2
        case .last4Weeks: return 4
        case .last8Weeks: return 8
        case .last12Weeks: return 12
        default: return nil
        }
    }
}

// MARK: - Time Period Enum
enum TimePeriod: Codable {
    case days(Int)
    case weeks(Int)
    case months(Int)

    var date: Date {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .days(let count):
            return calendar.date(byAdding: .day, value: -count, to: now) ?? now
        case .weeks(let count):
            return calendar.date(byAdding: .weekOfYear, value: -count, to: now) ?? now
        case .months(let count):
            return calendar.date(byAdding: .month, value: -count, to: now) ?? now
        }
    }
}

// MARK: - Mock Data Generation Functions
func generateMockTradePerformance(count: Int, successRate: Double, avgReturn: Double) -> [MockTradePerformance] {
    var trades: [MockTradePerformance] = []
    let calendar = Calendar.current
    let now = Date()

    for _ in 0..<count {
        // Generate investment cost (random between 1000 and 10000 for realistic ROI)
        let investmentCost = Double.random(in: 1_000...10_000)

        // Generate ROI in the range of -95% to +300%
        // Distribute based on successRate: higher successRate means more positive ROIs
        // But still include variety (some losses, some big wins, some moderate)
        let randomValue = Double.random(in: 0...1)
        let targetROI: Double

        if randomValue < successRate {
            // Successful trade: positive ROI between 0% and 300%
            // More trades near the lower end (realistic), but include some big wins
            if randomValue < successRate * 0.6 {
                // 60% of successful trades: moderate gains (0% to 50%)
                targetROI = Double.random(in: 0...50)
            } else if randomValue < successRate * 0.9 {
                // 30% of successful trades: good gains (50% to 150%)
                targetROI = Double.random(in: 50...150)
            } else {
                // 10% of successful trades: exceptional gains (150% to 300%)
                targetROI = Double.random(in: 150...300)
            }
        } else {
            // Unsuccessful trade: negative ROI between -95% and 0%
            // More trades near 0% (small losses), but include some big losses
            let lossRatio = (randomValue - successRate) / (1 - successRate)
            if lossRatio < 0.7 {
                // 70% of losses: small losses (-10% to 0%)
                targetROI = Double.random(in: -10...0)
            } else if lossRatio < 0.9 {
                // 20% of losses: moderate losses (-40% to -10%)
                targetROI = Double.random(in: -40...(-10))
            } else {
                // 10% of losses: significant losses (-95% to -40%)
                targetROI = Double.random(in: -95...(-40))
            }
        }

        // Calculate profit/loss from ROI
        let profitLoss = investmentCost * (targetROI / 100.0)

        // Generate dates spread over the past 3 months (approximately 90 days)
        // Each trade gets a different date
        let daysAgo = Int.random(in: 0...90)
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now

        let instruments = ["AAPL", "TSLA", "MSFT", "GOOGL", "AMZN", "NVDA", "META", "NFLX"]
        let instrument = instruments.randomElement() ?? "AAPL"
        let tradeType = Bool.random() ? "Buy" : "Sell"

        // Successful trade = ROI > 0
        let isSuccessfulBasedOnROI = targetROI > 0

        let trade = MockTradePerformance(
            date: date,
            profitLoss: profitLoss,
            investmentCost: investmentCost,
            isSuccessful: isSuccessfulBasedOnROI,
            instrument: instrument,
            tradeType: tradeType
        )

        trades.append(trade)
    }

    // Sort by date (most recent first)
    return trades.sorted { $0.date > $1.date }
}
