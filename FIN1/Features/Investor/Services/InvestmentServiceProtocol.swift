import Foundation
import SwiftUI
import Combine

// MARK: - Investment Service Protocol
/// Defines the contract for investment operations and portfolio management
protocol InvestmentServiceProtocol: ObservableObject {
    var investments: [Investment] { get }
    var investmentPools: [InvestmentPool] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var showError: Bool { get }

    // Publishers for observation (MVVM-friendly)
    var investmentsPublisher: AnyPublisher<[Investment], Never> { get }
    /// Publisher filtered per investor for isolation
    func investmentsPublisher(for investorId: String) -> AnyPublisher<[Investment], Never>
    /// Select next eligible investment for a trader using fair round-robin allocation
    func selectNextInvestmentForTrader(_ traderId: String) async -> Investment?
    /// Select next eligible investment for a specific investor using fair round-robin allocation
    /// This ensures each investor gets fair representation (one investment per investor per trade)
    func selectNextInvestmentForInvestor(_ investorId: String, traderId: String) async -> Investment?

    // MARK: - Investment Creation
    func createInvestment(
        investor: User,
        trader: MockTrader,
        amountPerInvestment: Double,
        numberOfInvestments: Int,
        specialization: String,
        potSelection: InvestmentSelectionStrategy
    ) async throws

    // MARK: - Investment Queries
    func getInvestments(for investorId: String) -> [Investment]
    func getInvestments(forTrader traderId: String) -> [Investment]
    func getInvestmentPools(forTrader traderId: String) -> [InvestmentPool]
    func getGroupedInvestmentsBySequence(forTrader traderId: String) -> [Int: [Investment]]

    // MARK: - Investment Status Management
    /// Marks the first active investment reservation as active when trader starts trading
    func markInvestmentAsActive(for traderId: String) async
    /// Marks the first active investment reservation as completed when trade completes
    func markInvestmentAsCompleted(for traderId: String) async
    /// Marks the next reserved investment as active for a specific investment
    func markNextInvestmentAsActive(for investmentId: String) async
    /// Marks the active investment as completed for a specific investment
    func markActiveInvestmentAsCompleted(for investmentId: String) async
    /// Deletes a reserved investment and re-evaluates completion
    func deleteInvestment(investmentId: String, reservationId: String) async
    /// Checks and updates investment completion status for all investments
    func checkAndUpdateInvestmentCompletion() async
    /// Updates investment profits from completed trades
    func updateInvestmentProfitsFromTrades() async

    // MARK: - Post-Initialization Configuration
    /// Configures calculation services after initialization (to resolve circular dependencies)
    func configureCalculationServices(
        investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)?,
        commissionCalculationService: (any CommissionCalculationServiceProtocol)?
    )
}
