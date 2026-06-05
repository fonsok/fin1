import Foundation

// MARK: - Investment Profit Calculator
/// Trade-level ROI helpers for investment completion flows.
/// Monetary totals for investor UI use server collection bills (`ServerCalculatedReturnResolver`).
struct InvestmentProfitCalculator {

    /// Returns the trade's ROI for single-trade investments, or weighted average for multi-trade.
    /// - Parameters:
    ///   - participations: Trade participations for the investment
    ///   - tradeLifecycleService: Service providing completed trades
    /// - Returns: The trade's ROI percentage, or nil if no trades found
    static func getTradeROI(
        for participations: [PoolTradeParticipation],
        tradeLifecycleService: any TradeLifecycleServiceProtocol
    ) -> Double? {
        guard !participations.isEmpty else { return nil }

        let trades = tradeLifecycleService.completedTrades
        var weightedROI = 0.0
        var totalWeight = 0.0

        for participation in participations {
            guard let trade = trades.first(where: { $0.id == participation.tradeId }) else { continue }

            let tradeROI = trade.displayROI
            let weight = participation.ownershipPercentage

            weightedROI += tradeROI * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return nil }

        return weightedROI / totalWeight
    }
}
