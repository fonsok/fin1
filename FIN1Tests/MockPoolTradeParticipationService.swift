import Foundation
import Combine
@testable import FIN1

final class MockPoolTradeParticipationService: PoolTradeParticipationServiceProtocol, @unchecked Sendable {
    @Published var participations: [PoolTradeParticipation] = []

    init() {}

    func recordPoolParticipation(
        tradeId: String,
        investmentId: String,
        poolReservationId: String,
        poolNumber: Int,
        allocatedAmount: Double,
        totalTradeValue: Double
    ) async {
        let participation = PoolTradeParticipation(
            tradeId: tradeId,
            investmentId: investmentId,
            poolReservationId: poolReservationId,
            poolNumber: poolNumber,
            allocatedAmount: allocatedAmount,
            totalTradeValue: totalTradeValue
        )
        await MainActor.run {
            participations.append(participation)
        }
    }

    func getParticipations(forTradeId tradeId: String) -> [PoolTradeParticipation] {
        participations.filter { $0.tradeId == tradeId }
    }

    func getParticipations(forInvestmentId investmentId: String) -> [PoolTradeParticipation] {
        participations.filter { $0.investmentId == investmentId }
    }

    func getParticipations(forPoolReservationId poolReservationId: String) -> [PoolTradeParticipation] {
        participations.filter { $0.poolReservationId == poolReservationId }
    }

    func distributeTradeProfit(tradeId: String, totalProfit: Double) async -> Double {
        // Mock: return 0.0 (no profit distributed in tests unless configured)
        return 0.0
    }

    func getAccumulatedProfit(for investmentId: String) -> Double {
        getParticipations(forInvestmentId: investmentId).compactMap { $0.profitShare }.reduce(0.0, +)
    }

    func getAccumulatedProfit(forPoolReservationId poolReservationId: String) -> Double {
        getParticipations(forPoolReservationId: poolReservationId).compactMap { $0.profitShare }.reduce(0.0, +)
    }

    func getAccumulatedProfit(forInvestmentReservationId investmentReservationId: String) -> Double {
        // Mock: find participations by investment reservation ID
        // Note: This might need to be mapped through investmentId if reservationId is stored differently
        // For now, return 0.0 as mock implementation
        return 0.0
    }
}
