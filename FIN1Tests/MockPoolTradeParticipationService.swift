import Foundation
import Combine
@testable import FIN1

final class MockPoolTradeParticipationService: PoolTradeParticipationServiceProtocol {
    var participations: [PoolTradeParticipation] = []

    init() {}

    func recordPoolParticipation(tradeId: String, investmentId: String, poolReservationId: String, poolNumber: Int, allocatedAmount: Double, totalTradeValue: Double) async {}

    func getParticipations(forTradeId tradeId: String) -> [PoolTradeParticipation] {
        participations.filter { $0.tradeId == tradeId }
    }

    func getParticipations(forInvestmentId investmentId: String) -> [PoolTradeParticipation] {
        participations.filter { $0.investmentId == investmentId }
    }

    func getParticipations(forPoolReservationId poolReservationId: String) -> [PoolTradeParticipation] {
        participations.filter { $0.poolReservationId == poolReservationId }
    }

    func distributeTradeProfit(tradeId: String, totalProfit: Double) async -> Double { 0.0 }

    func getAccumulatedProfit(for investmentId: String) -> Double {
        getParticipations(forInvestmentId: investmentId).compactMap { $0.profitShare }.reduce(0.0, +)
    }

    func getAccumulatedProfit(forPoolReservationId poolReservationId: String) -> Double {
        getParticipations(forPoolReservationId: poolReservationId).compactMap { $0.profitShare }.reduce(0.0, +)
    }
}
