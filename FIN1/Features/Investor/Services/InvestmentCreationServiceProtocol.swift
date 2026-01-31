import Foundation

// MARK: - Investment Creation Service Protocol
/// Defines the contract for investment creation operations
protocol InvestmentCreationServiceProtocol {
    func createInvestment(
        investor: User,
        trader: MockTrader,
        amountPerInvestment: Double,
        numberOfInvestments: Int,
        specialization: String,
        potSelection: InvestmentSelectionStrategy,
        repository: any InvestmentRepositoryProtocol
    ) async throws
}
