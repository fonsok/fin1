import Combine
import Foundation

/// Service for tracking and managing pool-trade participation
/// Tracks which investment pools are involved in which trades for profit distribution
protocol PoolTradeParticipationServiceProtocol: ObservableObject, Sendable {
    /// All pool-trade participations
    var participations: [PoolTradeParticipation] { get }

    /// Record pool participation in a trade
    /// Called when a buy order is placed that uses pool money
    func recordPoolParticipation(
        tradeId: String,
        investmentId: String,
        poolReservationId: String,
        poolNumber: Int,
        allocatedAmount: Double,
        totalTradeValue: Double
    ) async

    /// Get all participations for a specific trade
    func getParticipations(forTradeId tradeId: String) -> [PoolTradeParticipation]

    /// Get all participations for a specific investment
    func getParticipations(forInvestmentId investmentId: String) -> [PoolTradeParticipation]

    /// Get all participations for a specific pool reservation
    func getParticipations(forPoolReservationId poolReservationId: String) -> [PoolTradeParticipation]

    /// Distribute profit from a completed trade to participating pools
    /// Returns the total profit distributed to pools
    func distributeTradeProfit(
        tradeId: String,
        totalProfit: Double
    ) async -> Double

    /// Get accumulated profit for an investment from all completed trades
    func getAccumulatedProfit(for investmentId: String) -> Double

    /// Get accumulated profit for a specific pool reservation from all completed trades
    /// - Parameter poolReservationId: The pool reservation ID
    /// - Returns: Total profit accumulated for this pool reservation
    func getAccumulatedProfit(forPoolReservationId poolReservationId: String) -> Double

    /// Get accumulated profit for a specific investment reservation from all completed trades
    /// - Parameter investmentReservationId: The investment reservation ID
    /// - Returns: Total profit accumulated for this investment reservation
    func getAccumulatedProfit(forInvestmentReservationId investmentReservationId: String) -> Double
}
