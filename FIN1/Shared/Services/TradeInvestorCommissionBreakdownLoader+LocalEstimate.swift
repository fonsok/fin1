import Foundation

extension TradeInvestorCommissionBreakdownLoader {

    /// Local estimation via `InvestorGrossProfitService` — Phase 3: tests / `investorMonetaryServerOnly == false` only.
    @MainActor
    static func loadLocalEstimate(
        tradeId: String,
        investmentIds: [String],
        investments: [Investment],
        investorGrossProfitService: any InvestorGrossProfitServiceProtocol,
        commissionCalculationService: any CommissionCalculationServiceProtocol,
        commissionRate: Double
    ) async -> [TradeInvestorCommissionLine] {
        var lines: [TradeInvestorCommissionLine] = []

        for investmentId in investmentIds {
            guard let investment = investments.first(where: { $0.id == investmentId }) else { continue }
            do {
                let gross = try await investorGrossProfitService.getGrossProfit(
                    for: investmentId,
                    tradeId: tradeId
                )
                let commission = try await commissionCalculationService.calculateCommissionForInvestor(
                    investmentId: investmentId,
                    tradeId: tradeId,
                    commissionRate: commissionRate
                )
                lines.append(TradeInvestorCommissionLine(
                    investmentId: investmentId,
                    investorName: investment.investorName,
                    grossProfit: gross,
                    commission: commission
                ))
            } catch {
                print("⚠️ TradeInvestorCommissionBreakdownLoader [local]: \(investmentId) — \(error.localizedDescription)")
            }
        }

        return lines.sorted { $0.investorName < $1.investorName }
    }
}
