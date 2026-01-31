import Foundation

// MARK: - Investment Query Service Implementation
/// Handles investment query operations
final class InvestmentQueryService: InvestmentQueryServiceProtocol {

    /// Gets all investments for a specific investor
    func getInvestments(for investorId: String, in investments: [Investment]) -> [Investment] {
        return investments.filter { $0.investorId == investorId }
    }

    /// Gets all investments for a specific trader
    func getInvestments(forTrader traderId: String, in investments: [Investment]) -> [Investment] {
        return investments.filter { $0.traderId == traderId }
    }

    /// Gets all investment pools for a specific trader
    func getInvestmentPools(
        forTrader traderId: String,
        in investmentPools: [InvestmentPool],
        investmentManagementService: (any InvestmentManagementServiceProtocol)?
    ) -> [InvestmentPool] {
        if let investmentManagementService = investmentManagementService {
            return investmentManagementService.getInvestmentPools(forTrader: traderId)
        }
        return investmentPools.filter { $0.traderId == traderId }
    }

    /// Groups investments by sequence number for a specific trader
    func getGroupedInvestmentsBySequence(
        forTrader traderId: String,
        in investments: [Investment],
        investmentManagementService: (any InvestmentManagementServiceProtocol)?
    ) -> [Int: [Investment]] {
        if let investmentManagementService = investmentManagementService {
            return investmentManagementService.getGroupedInvestmentsBySequence(forTrader: traderId, in: investments)
        }
        // Fallback implementation - group by sequence number
        let traderInvestments = investments.filter { $0.traderId == traderId }
        var groupedInvestments: [Int: [Investment]] = [:]

        for investment in traderInvestments {
            let sequenceNumber = investment.sequenceNumber ?? 1
            if groupedInvestments[sequenceNumber] == nil {
                groupedInvestments[sequenceNumber] = []
            }
            groupedInvestments[sequenceNumber]?.append(investment)
        }

        return groupedInvestments
    }
}
