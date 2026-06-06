import Foundation

/// Resolves whether an Investment-Pool is **active** for a specific depot position (trader leg).
///
/// Investor-Schutz: Reserviertes Kapital (RSV) ohne ausgeführten Paired Buy erscheint nicht als „active“ —
/// nur Positionen mit Mirror-Pool-Leg oder dokumentierter Pool-Teilnahme am Trade.
enum DepotPositionPoolStatusResolver {

    static func isPoolActive(
        for holding: DepotHolding,
        completedTrades: [Trade],
        participations: [PoolTradeParticipation]
    ) -> Bool {
        let tradeId = holding.tradeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tradeId.isEmpty else { return false }

        if participations.contains(where: { $0.tradeId == tradeId }) {
            return true
        }

        guard let pairExecutionId = normalizedPairExecutionId(holding.pairExecutionId) else {
            return false
        }

        return completedTrades.contains { trade in
            trade.pairExecutionId == pairExecutionId && TraderDepotTradeFilter.isPoolMirrorLeg(trade)
        }
    }

    static func displayValue(
        for holding: DepotHolding,
        completedTrades: [Trade],
        participations: [PoolTradeParticipation]
    ) -> String {
        self.isPoolActive(
            for: holding,
            completedTrades: completedTrades,
            participations: participations
        ) ? "active" : "-"
    }

    private static func normalizedPairExecutionId(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
