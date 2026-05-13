import Combine
import Foundation

// MARK: - Investment Pool Lifecycle Service Protocol
/// Pools, reservation/status transitions, and fair round-robin selection for investor–trader investments.
protocol InvestmentPoolLifecycleServiceProtocol: ServiceLifecycle {
    /// Investment pools owned by this service
    var investmentPools: [InvestmentPool] { get }

    /// Creates investment reservations for an investment
    /// - Parameters:
    ///   - investment: The investment to create reservations for
    ///   - trader: The trader associated with the investment
    /// - Returns: Array of investment reservations
    func createInvestmentReservations(for investment: Investment, trader: MockTrader) -> [InvestmentReservation]

    /// Creates a new investment pool for a trader
    /// - Parameters:
    ///   - traderId: The trader's ID
    ///   - sequenceNumber: The sequence number
    ///   - amountPerInvestment: The amount per investment
    /// - Returns: A new InvestmentPool
    func createNewInvestmentPool(for traderId: String, sequenceNumber: Int, amountPerInvestment: Double) -> InvestmentPool

    /// Marks the first reserved investment as active for a trader
    /// - Parameters:
    ///   - traderId: The trader's ID
    ///   - investments: Current investments array
    /// - Returns: Updated investment if an investment was marked active, nil otherwise
    func markInvestmentAsActive(for traderId: String, in investments: [Investment]) -> Investment?

    /// Marks the first active investment as completed for a trader
    /// - Parameters:
    ///   - traderId: The trader's ID
    ///   - investments: Current investments array
    /// - Returns: Tuple of (updated investment, completed investment reservation) if an investment was marked completed, nil otherwise
    func markInvestmentAsCompleted(for traderId: String, in investments: [Investment]) -> (Investment, InvestmentReservation)?

    /// Marks the next reserved investment as active for a specific investment
    /// - Parameters:
    ///   - investmentId: The investment ID
    ///   - investments: Current investments array
    /// - Returns: Updated investment if an investment was marked active, nil otherwise
    func markNextInvestmentAsActive(for investmentId: String, in investments: [Investment]) -> Investment?

    /// Marks the active investment as completed for a specific investment
    /// - Parameters:
    ///   - investmentId: The investment ID
    ///   - investments: Current investments array
    /// - Returns: Tuple of (updated investment, completed investment reservation) if an investment was marked completed, nil otherwise
    func markActiveInvestmentAsCompleted(for investmentId: String, in investments: [Investment]) -> (Investment, InvestmentReservation)?

    /// Deletes a reserved investment
    /// - Parameters:
    ///   - investmentId: The investment ID
    ///   - reservationId: The reservation ID to delete (kept for backward compatibility)
    ///   - investments: Current investments array
    /// - Returns: Updated investment if reservation was deleted, nil otherwise
    /// - Note: Since each investment is now a first-class entity, this method returns nil as deletion is handled directly
    func deleteInvestment(investmentId: String, reservationId: String, in investments: [Investment]) -> Investment?

    /// Select next eligible investment for a trader using fair round-robin allocation
    /// - Parameters:
    ///   - traderId: The trader's ID
    ///   - investments: Current investments array
    /// - Returns: The next eligible investment, or nil if none available
    func selectNextInvestmentForTrader(_ traderId: String, in investments: [Investment]) -> Investment?

    /// Select next eligible investment for a specific investor using fair round-robin allocation
    /// This ensures each investor gets fair representation (one investment per investor per trade)
    /// - Parameters:
    ///   - investorId: The investor's ID
    ///   - traderId: The trader's ID
    ///   - investments: Current investments array
    /// - Returns: The next eligible investment for this investor, or nil if none available
    func selectNextInvestmentForInvestor(_ investorId: String, traderId: String, in investments: [Investment]) -> Investment?

    /// Gets all investment pools for a specific trader
    /// - Parameter traderId: The trader's ID
    /// - Returns: Array of investment pools for the trader
    func getInvestmentPools(forTrader traderId: String) -> [InvestmentPool]

    /// Groups investments by sequence number for a specific trader
    /// - Parameters:
    ///   - traderId: The trader's ID
    ///   - investments: Current investments array
    /// - Returns: Dictionary mapping sequence numbers to investments
    func getGroupedInvestmentsBySequence(forTrader traderId: String, in investments: [Investment]) -> [Int: [Investment]]
}
