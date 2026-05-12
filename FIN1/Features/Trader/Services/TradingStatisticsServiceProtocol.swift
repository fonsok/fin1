import Foundation
import Combine

// MARK: - Trading Statistics Service Protocol
/// Defines the contract for trading statistics calculations and management
protocol TradingStatisticsServiceProtocol: ObservableObject, Sendable {
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // MARK: - Statistics Calculations
    func calculateTotalVolume(activeOrders: [Order], completedTrades: [Trade]) -> Double
    func calculateDailyPnL(completedTrades: [Trade]) -> Double
    func calculateTotalPnL(completedTrades: [Trade]) -> Double
    func calculateWinRate(completedTrades: [Trade]) -> Double
    func calculateAverageTradeSize(completedTrades: [Trade]) -> Double

    // MARK: - Trade Calculations
    func calculateGrossProfit(for trade: Trade) -> Double
    func calculateTotalFees(for trade: Trade) -> Double

    // MARK: - Statistics Data Management
    func loadTradingStats() async throws
    func refreshTradingStats() async throws
}
