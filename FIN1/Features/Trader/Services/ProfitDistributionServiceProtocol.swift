import Foundation

// MARK: - Profit Distribution Service Protocol
/// Defines the contract for profit distribution operations
/// Handles commission calculation, trader payment, and profit distribution to investments
protocol ProfitDistributionServiceProtocol {
    /// Distributes profit for a completed trade
    /// - Parameters:
    ///   - trade: The completed trade
    ///   - order: The order that completed the trade
    /// - Returns: The total distributed profit amount
    func distributeProfit(for trade: Trade, order: Order) async -> Double
}
