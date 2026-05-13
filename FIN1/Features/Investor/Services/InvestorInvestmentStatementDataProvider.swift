import Foundation

protocol InvestorInvestmentStatementDataProviderProtocol: Sendable {
    func resolveContext(
        for investment: Investment,
        localParticipations: [PoolTradeParticipation],
        localTrades: [Trade]
    ) async -> InvestorInvestmentStatementResolvedContext
}

struct InvestorInvestmentStatementResolvedContext {
    let participations: [PoolTradeParticipation]
    let tradesById: [String: Trade]
}

final class InvestorInvestmentStatementDataProvider: InvestorInvestmentStatementDataProviderProtocol, @unchecked Sendable {
    private let parseAPIClient: (any ParseAPIClientProtocol)?

    init(parseAPIClient: (any ParseAPIClientProtocol)?) {
        self.parseAPIClient = parseAPIClient
    }

    func resolveContext(
        for investment: Investment,
        localParticipations: [PoolTradeParticipation],
        localTrades: [Trade]
    ) async -> InvestorInvestmentStatementResolvedContext {
        let participations = await resolveParticipations(
            investment: investment,
            localParticipations: localParticipations
        )
        let tradesById = await resolveTradesById(
            participations: participations,
            localTrades: localTrades
        )
        return InvestorInvestmentStatementResolvedContext(
            participations: participations,
            tradesById: tradesById
        )
    }

    private func resolveParticipations(
        investment: Investment,
        localParticipations: [PoolTradeParticipation]
    ) async -> [PoolTradeParticipation] {
        if !localParticipations.isEmpty { return localParticipations }
        guard let parseAPIClient else { return [] }

        let candidateIds = [investment.id, investment.batchId]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var fetched: [PoolTradeParticipation] = []
        for candidate in candidateIds {
            do {
                let rows: [BackendPoolParticipationRow] = try await parseAPIClient.fetchObjects(
                    className: "PoolTradeParticipation",
                    query: ["investmentId": candidate],
                    include: nil,
                    orderBy: "-createdAt",
                    limit: 200
                )
                fetched.append(contentsOf: rows.compactMap { $0.toModel() })
            } catch {
                print(
                    "⚠️ InvestorInvestmentStatementDataProvider: participation fetch failed for '\(candidate)': \(error.localizedDescription)"
                )
            }
        }

        var unique: [String: PoolTradeParticipation] = [:]
        for item in fetched {
            unique[item.id] = item
        }
        return Array(unique.values)
    }

    private func resolveTradesById(
        participations: [PoolTradeParticipation],
        localTrades: [Trade]
    ) async -> [String: Trade] {
        var resolvedById: [String: Trade] = [:]
        for trade in localTrades {
            resolvedById[trade.id] = trade
        }

        guard let parseAPIClient else { return resolvedById }
        let missingTradeIds = Set(participations.map(\.tradeId)).filter { resolvedById[$0] == nil }
        for tradeId in missingTradeIds {
            do {
                let parseTrade: ParseTrade = try await parseAPIClient.fetchObject(
                    className: "Trade",
                    objectId: tradeId,
                    include: nil
                )
                let trade = try parseTrade.toTrade()
                resolvedById[trade.id] = trade
            } catch {
                print("⚠️ InvestorInvestmentStatementDataProvider: trade fetch failed for '\(tradeId)': \(error.localizedDescription)")
            }
        }
        return resolvedById
    }
}

private struct BackendPoolParticipationRow: Decodable {
    let objectId: String
    let tradeId: String?
    let investmentId: String?
    let poolReservationId: String?
    let poolNumber: Int?
    let allocatedAmount: Double?
    let totalTradeValue: Double?
    let ownershipPercentage: Double?
    let profitShare: Double?
    let createdAt: FlexibleParseDate?
    let updatedAt: FlexibleParseDate?

    func toModel() -> PoolTradeParticipation? {
        guard
            let tradeId, !tradeId.isEmpty,
            let investmentId, !investmentId.isEmpty
        else {
            return nil
        }

        let totalTradeValue = self.totalTradeValue ?? 0
        let allocatedAmount = self.allocatedAmount ?? 0
        let rawOwnership = self.ownershipPercentage ?? (totalTradeValue > 0 ? allocatedAmount / totalTradeValue : 0)
        let normalizedOwnership = rawOwnership > 1.0 ? rawOwnership / 100.0 : rawOwnership

        return PoolTradeParticipation(
            id: self.objectId,
            tradeId: tradeId,
            investmentId: investmentId,
            poolReservationId: self.poolReservationId ?? "",
            poolNumber: self.poolNumber ?? 0,
            allocatedAmount: allocatedAmount,
            totalTradeValue: totalTradeValue,
            ownershipPercentage: normalizedOwnership,
            profitShare: self.profitShare,
            createdAt: self.createdAt?.toDate() ?? Date(),
            updatedAt: self.updatedAt?.toDate() ?? Date()
        )
    }
}
