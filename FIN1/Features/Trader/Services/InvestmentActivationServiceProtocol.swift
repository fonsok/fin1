import Foundation

// MARK: - Investment Activation Service Protocol
/// Defines the contract for investment activation operations
/// Handles activation of investments when buy orders complete
protocol InvestmentActivationServiceProtocol: Sendable {
    /// Activates investments for a completed buy order
    /// - Parameters:
    ///   - order: The completed buy order
    ///   - trade: The trade created from the buy order
    /// - Returns: Array of activated investment IDs
    func activateInvestmentsForBuyOrder(order: Order, trade: Trade) async -> [String]
}
