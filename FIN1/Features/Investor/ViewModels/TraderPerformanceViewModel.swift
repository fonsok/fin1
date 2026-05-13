import Foundation
import SwiftUI

// MARK: - Trader Performance ViewModel
@MainActor
final class TraderPerformanceViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var groupedWeeks: [WeekTradeData] = []
    @Published var chartDisplayData: ChartDisplayData = ChartDisplayData(weeks: [])
    @Published var selectedTimePeriod: TimePeriodOption = .last60Days
    @Published var viewMode: ViewMode = .table
    @Published var isLoading = false

    // MARK: - Enums
    enum TimePeriodOption: String, CaseIterable {
        case last30Days = "last 30 days"
        case last60Days = "last 60 days"
        case last90Days = "last 90 days"
        case lastYear = "last year"

        var days: Int {
            switch self {
            case .last30Days: return 30
            case .last60Days: return 60
            case .last90Days: return 90
            case .lastYear: return 365
            }
        }
    }

    enum ViewMode {
        case chart
        case table
    }

    // MARK: - Private Properties
    private let trader: MockTrader
    private let calendar = Calendar.current

    // MARK: - Initialization
    init(trader: MockTrader) {
        self.trader = trader
        self.processTrades()
    }

    // MARK: - Public Methods
    func updateTimePeriod(_ period: TimePeriodOption) {
        self.selectedTimePeriod = period
        self.processTrades()
    }

    func updateViewMode(_ mode: ViewMode) {
        self.viewMode = mode
    }

    // MARK: - Data Processing (Business Logic)
    private func processTrades() {
        self.isLoading = true
        defer { isLoading = false }

        let cutoffDate = self.calendar.date(byAdding: .day, value: -self.selectedTimePeriod.days, to: Date()) ?? Date()

        // Filter trades within selected time period
        let filteredTrades = self.trader.recentTrades.filter { $0.date >= cutoffDate }

        // Group by calendar week using a string key
        let grouped = Dictionary(grouping: filteredTrades) { trade in
            let year = self.calendar.component(.yearForWeekOfYear, from: trade.date)
            let week = self.calendar.component(.weekOfYear, from: trade.date)
            return "\(year)-\(week)"
        }

        // Convert to sorted array
        self.groupedWeeks = grouped.map { _, trades in
            let weekDate = trades.first?.date ?? Date()
            let weekNumber = self.calendar.component(.weekOfYear, from: weekDate)
            let year = self.calendar.component(.year, from: weekDate)
            let monthName = self.getMonthName(for: weekDate)

            // Create trade return data with active status detection
            let tradeReturns = trades.enumerated().map { index, trade in
                // Determine if trade is active: recent trades (within last 7 days) with "Buy" type
                // For mock data, we'll consider a trade active if it's a Buy and recent
                let daysSinceTrade = self.calendar.dateComponents([.day], from: trade.date, to: Date()).day ?? 0
                let isActive = trade.tradeType == "Buy" && daysSinceTrade <= 7 && trade.roi == 0

                // Trade number based on index (will be replaced with actual trade numbers when available)
                let tradeNumber = index + 1

                return TradeReturnData(
                    roi: trade.roi,
                    isActive: isActive,
                    tradeNumber: tradeNumber
                )
            }

            return WeekTradeData(
                week: weekNumber,
                month: monthName,
                year: year,
                date: weekDate,
                tradeReturns: tradeReturns
            )
        }
        .sorted { first, second in
            // Sort by date descending (most recent first)
            first.date > second.date
        }

        // Update chart display data when groupedWeeks changes
        self.chartDisplayData = ChartDisplayData(weeks: self.groupedWeeks)
    }

    // MARK: - Helper Methods
    private func getMonthName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date)
    }

    // MARK: - Computed Properties
    var hasTrades: Bool {
        !self.groupedWeeks.isEmpty
    }

    var totalTradesCount: Int {
        self.trader.recentTrades.count
    }

    var currentYear: Int {
        self.calendar.component(.year, from: Date())
    }
}

// MARK: - Chart Display Data
/// Processed chart data ready for display (all business logic processed in ViewModel)
struct ChartDisplayData {
    let allTrades: [ChartTradeItem]
    let monthGroups: [MonthChartGroup]
    let yAxisRange: (min: Double, max: Double)
    let yAxisLabels: [Double]
    let hasLogScaleValues: Bool

    init(weeks: [WeekTradeData]) {
        // Business logic: Flatten trades
        // Note: weeks are already sorted by date descending in processTrades()
        self.allTrades = weeks.flatMap { weekData in
            weekData.tradeReturns.map { ChartTradeItem(weekData: weekData, tradeReturn: $0) }
        }

        // Business logic: Group by month
        self.monthGroups = ChartDisplayData.processMonthGroups(trades: self.allTrades)

        // Business logic: Calculate Y-axis range
        self.yAxisRange = ChartDisplayData.calculateYAxisRange(trades: self.allTrades)

        // Business logic: Generate Y-axis labels
        self.yAxisLabels = ChartDisplayData.generateYAxisLabels(yAxisRange: self.yAxisRange)

        // Business logic: Check for log scale values
        self.hasLogScaleValues = self.allTrades.contains { $0.tradeReturn.roi > 200 }
    }

    private static func processMonthGroups(trades: [ChartTradeItem]) -> [MonthChartGroup] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "MMMM"
        var groups: [String: [ChartTradeItem]] = [:]
        var monthOrder: [String] = []
        for trade in trades {
            let monthKey = formatter.string(from: trade.weekData.date)
            if groups[monthKey] == nil {
                groups[monthKey] = []
                monthOrder.append(monthKey)
            }
            groups[monthKey]?.append(trade)
        }
        return monthOrder.map { MonthChartGroup(month: $0, trades: groups[$0] ?? []) }
    }

    private static func calculateYAxisRange(trades: [ChartTradeItem]) -> (min: Double, max: Double) {
        guard !trades.isEmpty else { return (min: -100, max: 200) }
        let rois = trades.map { $0.tradeReturn.roi }
        let minROI = rois.min() ?? -100
        let maxROI = rois.max() ?? 100
        var constrainedMin: Double = -100
        var constrainedMax: Double = 200
        if minROI < -100 { constrainedMin = max(minROI - 20, -100) }
        if maxROI > 200 { constrainedMax = maxROI * 1.1 }
        return (min: constrainedMin, max: constrainedMax)
    }

    private static func generateYAxisLabels(yAxisRange: (min: Double, max: Double)) -> [Double] {
        var labels: [Double] = []
        if yAxisRange.min <= -100 { labels.append(-100) }
        labels.append(0)
        labels.append(100)
        labels.append(200)
        if yAxisRange.max > 200 {
            let logLabels = self.generateLogScaleLabels(maxValue: yAxisRange.max)
            labels.append(contentsOf: logLabels)
        }
        return labels.sorted(by: >)
    }

    private static func generateLogScaleLabels(maxValue: Double) -> [Double] {
        var logLabels: [Double] = []
        let logSteps: [Double] = [200, 500, 1_000, 2_000, 5_000, 10_000]
        for step in logSteps {
            if step <= maxValue {
                logLabels.append(step)
            } else {
                break
            }
        }
        if logLabels.isEmpty || (logLabels.last ?? 0) < maxValue {
            let roundedMax = self.roundToSignificantValue(maxValue)
            if roundedMax > 200 && !logLabels.contains(roundedMax) {
                logLabels.append(roundedMax)
            }
        }
        return logLabels
    }

    private static func roundToSignificantValue(_ value: Double) -> Double {
        if value <= 500 { return 500 }
        if value <= 1_000 { return 1_000 }
        if value <= 2_000 { return 2_000 }
        if value <= 5_000 { return 5_000 }
        return ceil(value / 1_000) * 1_000
    }
}

// MARK: - Chart Data Models
struct ChartTradeItem: Identifiable {
    let id: String
    let weekData: WeekTradeData
    let tradeReturn: TradeReturnData

    init(weekData: WeekTradeData, tradeReturn: TradeReturnData) {
        self.id = "\(weekData.id)-\(tradeReturn.id)"
        self.weekData = weekData
        self.tradeReturn = tradeReturn
    }
}

struct MonthChartGroup {
    let month: String
    let trades: [ChartTradeItem]
}

// MARK: - Week Trade Data
struct WeekTradeData: Identifiable {
    let id: String
    let week: Int
    let month: String
    let year: Int
    let date: Date
    let tradeReturns: [TradeReturnData]

    init(week: Int, month: String, year: Int, date: Date, tradeReturns: [TradeReturnData]) {
        self.id = "\(year)-\(week)-\(month)"
        self.week = week
        self.month = month
        self.year = year
        self.date = date
        self.tradeReturns = tradeReturns
    }

    // Convenience accessor for backward compatibility
    var returns: [Double] {
        self.tradeReturns.map { $0.roi }
    }
}

// MARK: - Trade Return Data
struct TradeReturnData: Identifiable {
    let id: String
    let roi: Double
    let isActive: Bool
    let tradeNumber: Int

    init(roi: Double, isActive: Bool, tradeNumber: Int) {
        self.id = UUID().uuidString
        self.roi = roi
        self.isActive = isActive
        self.tradeNumber = tradeNumber
    }
}
