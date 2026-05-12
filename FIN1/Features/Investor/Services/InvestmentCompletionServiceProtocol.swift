import Foundation

// MARK: - Investment Completion Service Protocol
/// Defines the contract for investment completion checking and profit calculation
@MainActor
protocol InvestmentCompletionServiceProtocol {
    /// Checks and updates investment completion status for all investments or specific ones
    /// - Parameters:
    ///   - investments: Current investments array
    ///   - specificInvestmentIds: Optional list of investment IDs to check. If nil, checks all.
    /// - Returns: Array of updated investments (only those that changed)
    func checkAndUpdateInvestmentCompletion(
        in investments: [Investment],
        specificInvestmentIds: [String]?
    ) -> [Investment]

    /// Updates investment profits from completed trades
    /// - Parameter investments: Current investments array
    /// - Returns: Array of updated investments (only those that changed)
    func updateInvestmentProfitsFromTrades(in investments: [Investment]) -> [Investment]

    /// Distributes cash balance update when an investment completes
    /// - Parameters:
    ///   - investment: The investment containing the completed investment
    ///   - investmentReservation: The completed investment reservation
    func distributeInvestmentCompletionCash(
        investment: Investment,
        investmentReservation: InvestmentReservation
    ) async
}
