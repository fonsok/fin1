import Foundation

// MARK: - Investment Query Service Protocol
/// Defines the contract for investment query operations
protocol InvestmentQueryServiceProtocol {
    func getInvestments(for investorId: String, in investments: [Investment]) -> [Investment]
    func getInvestments(forTrader traderId: String, in investments: [Investment]) -> [Investment]
    func getInvestmentPools(forTrader traderId: String, in investmentPools: [InvestmentPool], investmentManagementService: (any InvestmentManagementServiceProtocol)?) -> [InvestmentPool]
    func getGroupedInvestmentsBySequence(
        forTrader traderId: String,
        in investments: [Investment],
        investmentManagementService: (any InvestmentManagementServiceProtocol)?
    ) -> [Int: [Investment]]
}
