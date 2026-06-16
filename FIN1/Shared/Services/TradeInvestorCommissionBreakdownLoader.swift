import Foundation

/// One investor's commission line for a trade (server beleg or settlement).
struct TradeInvestorCommissionLine: Identifiable, Equatable {
    let investmentId: String
    let investorName: String
    let grossProfit: Double
    let commission: Double

    var id: String { self.investmentId }
}

/// Phase 3: loads trader commission breakdown from backend settlement / collection bills.
/// Local `InvestorGrossProfitService` is not used here (preview/tests only).
enum TradeInvestorCommissionBreakdownLoader {

    @MainActor
    static func load(
        tradeId: String,
        investmentIds: [String],
        investments: [Investment],
        settlementAPIService: any SettlementAPIServiceProtocol
    ) async -> [TradeInvestorCommissionLine]? {
        let uniqueIds = Array(Set(investmentIds))
        guard !uniqueIds.isEmpty else { return nil }

        if let fromSettlement = await loadFromTradeSettlement(
            tradeId: tradeId,
            investmentIds: uniqueIds,
            investments: investments,
            api: settlementAPIService
        ) {
            return fromSettlement
        }

        return await self.loadFromCollectionBills(
            tradeId: tradeId,
            investmentIds: uniqueIds,
            investments: investments,
            api: settlementAPIService
        )
    }

    @MainActor
    private static func loadFromTradeSettlement(
        tradeId: String,
        investmentIds: [String],
        investments: [Investment],
        api: any SettlementAPIServiceProtocol
    ) async -> [TradeInvestorCommissionLine]? {
        guard let settlement = try? await api.fetchTradeSettlement(tradeId: tradeId),
              settlement.isSettledByBackend,
              !settlement.commissions.isEmpty else {
            return nil
        }

        var lines: [TradeInvestorCommissionLine] = []
        for investmentId in investmentIds {
            let rows = settlement.commissions.filter { $0.investmentId == investmentId }
            let commission = rows.compactMap(\.commissionAmount).reduce(0, +)
            let gross = rows.compactMap(\.investorGrossProfit).reduce(0, +)
            guard commission > 0 || gross > 0 else { continue }

            let name = TradeInvestorCommissionNameResolver.resolve(
                investmentId: investmentId,
                investorId: rows.first?.investorId,
                investments: investments
            )
            lines.append(TradeInvestorCommissionLine(
                investmentId: investmentId,
                investorName: name,
                grossProfit: gross,
                commission: commission
            ))
        }

        guard !lines.isEmpty else { return nil }
        return lines.sorted { $0.investorName < $1.investorName }
    }

    @MainActor
    private static func loadFromCollectionBills(
        tradeId: String,
        investmentIds: [String],
        investments: [Investment],
        api: any SettlementAPIServiceProtocol
    ) async -> [TradeInvestorCommissionLine]? {
        var lines: [TradeInvestorCommissionLine] = []

        for investmentId in investmentIds {
            guard let investment = investments.first(where: { $0.id == investmentId }) else {
                return nil
            }

            let response: BackendCollectionBillResponse
            do {
                response = try await api.fetchInvestorCollectionBills(
                    limit: 20,
                    skip: 0,
                    investmentId: investmentId,
                    tradeId: tradeId
                )
            } catch {
                return nil
            }

            guard let bill = response.collectionBills.first,
                  let metadata = bill.metadata else {
                return nil
            }

            let commission = metadata.commission?.doubleValue ?? 0
            let gross = metadata.grossProfit?.doubleValue ?? 0
            guard commission > 0 || gross > 0 else { return nil }

            lines.append(TradeInvestorCommissionLine(
                investmentId: investmentId,
                investorName: TradeInvestorCommissionNameResolver.resolve(
                    investmentId: investmentId,
                    investorId: investment.investorId,
                    investments: investments
                ),
                grossProfit: gross,
                commission: commission
            ))
        }

        guard !lines.isEmpty else { return nil }
        return lines.sorted { $0.investorName < $1.investorName }
    }
}
