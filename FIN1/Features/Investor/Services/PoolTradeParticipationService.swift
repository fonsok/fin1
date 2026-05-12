import Foundation
import Combine

/// Implementation of PoolTradeParticipationService
/// Now syncs participations to Parse Server for admin visibility
final class PoolTradeParticipationService: PoolTradeParticipationServiceProtocol, ServiceLifecycle, @unchecked Sendable {
    @Published var participations: [PoolTradeParticipation] = []

    private var investmentAPIService: InvestmentAPIServiceProtocol?

    init(investmentAPIService: InvestmentAPIServiceProtocol? = nil) {
        self.investmentAPIService = investmentAPIService
    }

    /// Configure the API service (for late binding in DI)
    func configure(investmentAPIService: InvestmentAPIServiceProtocol) {
        self.investmentAPIService = investmentAPIService
    }

    // MARK: - ServiceLifecycle

    func start() {
        // Load participations from persistent storage if needed
        // For now, participations are in-memory only
    }

    func stop() {
        // Clean up any ongoing operations
        // Participations remain in memory
    }

    func reset() {
        // Clear all participations (useful for testing)
        participations.removeAll()
    }

    // MARK: - PoolTradeParticipationServiceProtocol

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

        // Store locally
        await MainActor.run {
            participations.append(participation)
        }

        print("📝 PoolTradeParticipationService: Recorded participation")
        print("   Trade ID: \(tradeId)")
        print("   Investment ID: \(investmentId)")
        print("   Pool Reservation ID: \(poolReservationId)")
        print("   Pool Number: \(poolNumber)")
        print("   Allocated Amount: €\(String(format: "%.2f", allocatedAmount))")
        print("   Total Trade Value: €\(String(format: "%.2f", totalTradeValue))")
        print("   Ownership %: \(String(format: "%.2f", participation.ownershipPercentage * 100))%")

        // Sync to Parse Server
        if let apiService = investmentAPIService {
            do {
                let savedParticipation = try await apiService.createPoolParticipation(participation)
                // Update local participation with server ID
                await MainActor.run {
                    if let index = participations.firstIndex(where: { $0.id == participation.id }) {
                        participations[index] = savedParticipation
                    }
                }
                print("✅ PoolTradeParticipationService: Synced to Parse Server")
            } catch {
                print("⚠️ PoolTradeParticipationService: Failed to sync to Parse Server: \(error)")
            }
        }
    }

    func getParticipations(forTradeId tradeId: String) -> [PoolTradeParticipation] {
        return participations.filter { $0.tradeId == tradeId }
    }

    func getParticipations(forInvestmentId investmentId: String) -> [PoolTradeParticipation] {
        return participations.filter { $0.investmentId == investmentId }
    }

    func getParticipations(forPoolReservationId poolReservationId: String) -> [PoolTradeParticipation] {
        return participations.filter { $0.poolReservationId == poolReservationId }
    }

    func distributeTradeProfit(
        tradeId: String,
        totalProfit: Double
    ) async -> Double {
        await MainActor.run {
            let tradeParticipations = getParticipations(forTradeId: tradeId)
            guard !tradeParticipations.isEmpty else {
                print("⚠️ PoolTradeParticipationService: No participations found for trade \(tradeId)")
                return 0.0
            }

            var totalDistributed: Double = 0.0

            // Distribute profit proportionally based on ownership percentage
            for participation in tradeParticipations {
                let profitShare = totalProfit * participation.ownershipPercentage
                totalDistributed += profitShare

                // Update participation with profit share
                if let index = participations.firstIndex(where: { $0.id == participation.id }) {
                    participations[index] = participation.withProfitShare(profitShare)
                }

                print("💰 PoolTradeParticipationService: Distributed profit")
                print("   Trade ID: \(tradeId)")
                print("   Investment ID: \(participation.investmentId)")
                print("   Pool Number: \(participation.poolNumber)")
                print("   Ownership %: \(String(format: "%.2f", participation.ownershipPercentage * 100))%")
                print("   Profit Share: €\(String(format: "%.2f", profitShare))")
            }

            print("✅ PoolTradeParticipationService: Distributed total profit of €\(String(format: "%.2f", totalDistributed)) to \(tradeParticipations.count) pools")
            return totalDistributed
        }
    }

    func getAccumulatedProfit(for investmentId: String) -> Double {
        let investmentParticipations = getParticipations(forInvestmentId: investmentId)
        return investmentParticipations.compactMap { $0.profitShare }.reduce(0.0, +)
    }

    func getAccumulatedProfit(forPoolReservationId poolReservationId: String) -> Double {
        let poolParticipations = getParticipations(forPoolReservationId: poolReservationId)
        return poolParticipations.compactMap { $0.profitShare }.reduce(0.0, +)
    }

    func getAccumulatedProfit(forInvestmentReservationId investmentReservationId: String) -> Double {
        // Alias for backward compatibility - investment reservation ID is the same as pool reservation ID
        return getAccumulatedProfit(forPoolReservationId: investmentReservationId)
    }
}
