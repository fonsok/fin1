import Foundation
import Combine

// MARK: - Trading Statistics Service Implementation
/// Handles trading statistics calculations and management
final class TradingStatisticsService: TradingStatisticsServiceProtocol, ServiceLifecycle {

    @Published var isLoading = false
    @Published var errorMessage: String?

    init() {
        // No initial data loading needed for statistics service
    }

    // MARK: - ServiceLifecycle
    func start() {
        // Statistics service doesn't need to load data on start
        // It calculates statistics based on provided data
    }

    func stop() {
        // Clean up any ongoing operations
    }

    func reset() {
        errorMessage = nil
    }

    // MARK: - Statistics Data Management

    func loadTradingStats() async throws {
        await MainActor.run {
            isLoading = true
        }

        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        await MainActor.run {
            isLoading = false
        }
    }

    func refreshTradingStats() async throws {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        await MainActor.run {
            isLoading = false
        }
    }

    // MARK: - Statistics Calculations

    func calculateTotalVolume(activeOrders: [Order], completedTrades: [Trade]) -> Double {
        let activeVolume = activeOrders.reduce(0) { $0 + $1.totalAmount }
        let completedVolume = completedTrades.reduce(0) { $0 + ($1.buyOrder.totalAmount + ($1.sellOrder?.totalAmount ?? 0)) }
        return activeVolume + completedVolume
    }

    func calculateDailyPnL(completedTrades: [Trade]) -> Double {
        // Mock calculation - in real app, this would calculate actual daily P&L
        // Filter trades by today's date and calculate P&L
        let today = Calendar.current.startOfDay(for: Date())
        let todayTrades = completedTrades.filter { trade in
            guard let completedAt = trade.completedAt else { return false }
            return Calendar.current.isDate(completedAt, inSameDayAs: today)
        }

        return calculatePnL(for: todayTrades)
    }

    func calculateTotalPnL(completedTrades: [Trade]) -> Double {
        return calculatePnL(for: completedTrades)
    }

    func calculateWinRate(completedTrades: [Trade]) -> Double {
        guard !completedTrades.isEmpty else { return 0.0 }

        let profitableTrades = completedTrades.filter { trade in
            calculateTradePnL(trade) > 0
        }

        return Double(profitableTrades.count) / Double(completedTrades.count) * 100.0
    }

    func calculateAverageTradeSize(completedTrades: [Trade]) -> Double {
        guard !completedTrades.isEmpty else { return 0.0 }

        let totalVolume = completedTrades.reduce(0) { $0 + $1.buyOrder.totalAmount }
        return totalVolume / Double(completedTrades.count)
    }

    // MARK: - Private Methods

    private func calculatePnL(for trades: [Trade]) -> Double {
        return trades.reduce(0) { total, trade in
            total + calculateTradePnL(trade)
        }
    }

    private func calculateTradePnL(_ trade: Trade) -> Double {
        guard trade.sellOrder != nil else {
            // If no sell order, P&L is 0 (position still open)
            return 0.0
        }

        // Use centralized profit calculation service to avoid DRY violations
        return ProfitCalculationService.calculateGrossProfitFromOrders(for: trade)
    }

    /// Calculate total fees for an order amount
    private func calculateOrderFees(for orderAmount: Double) -> Double {
        // Use centralized fee calculation service
        return FeeCalculationService.calculateTotalFees(for: orderAmount)
    }

    /// Calculate gross profit (before taxes) for a trade - matches Trade Details calculation
    func calculateGrossProfit(for trade: Trade) -> Double {
        // Use centralized profit calculation service
        return ProfitCalculationService.calculateGrossProfitFromOrders(for: trade)
    }

    /// Calculate total fees for a trade - net fee impact on profit
    func calculateTotalFees(for trade: Trade) -> Double {
        // Check both legacy sellOrder and new sellOrders array
        let sellOrders = trade.sellOrders.isEmpty ? (trade.sellOrder.map { [$0] } ?? []) : trade.sellOrders

        guard !sellOrders.isEmpty else {
            return 0.0
        }

        // Calculate fees based on securities value (price * quantity)
        let buySecuritiesValue = trade.buyOrder.price * Double(trade.buyOrder.quantity)
        let sellSecuritiesValue = sellOrders.reduce(0) { $0 + ($1.price * Double($1.quantity)) }

        let buyFees = calculateOrderFees(for: buySecuritiesValue)
        let sellFees = calculateOrderFees(for: sellSecuritiesValue)

        // Return net fee impact: sell fees reduce profit, buy fees reduce profit
        // This represents the total fee burden on the trade
        return buyFees + sellFees
    }
}
