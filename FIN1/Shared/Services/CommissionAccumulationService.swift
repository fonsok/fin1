import Foundation

// MARK: - Commission Accumulation Service Protocol

protocol CommissionAccumulationServiceProtocol: ServiceLifecycle {
    /// Records a commission accumulation for an investor from a trade
    func recordCommission(
        investorId: String,
        traderId: String,
        tradeId: String,
        tradeNumber: Int,
        commissionAmount: Double,
        grossProfit: Double
    ) async

    /// Gets all unsettled commission accumulations for a specific trader
    func getUnsettledCommissions(for traderId: String) -> [CommissionAccumulation]

    /// Gets all unsettled commission accumulations for a specific investor
    func getUnsettledCommissions(forInvestor investorId: String) -> [CommissionAccumulation]

    /// Gets all unsettled commission accumulations grouped by trader
    func getUnsettledCommissionsByTrader() -> [String: [CommissionAccumulation]]

    /// Gets all unsettled commission accumulations grouped by investor
    func getUnsettledCommissionsByInvestor() -> [String: [CommissionAccumulation]]

    /// Marks commissions as settled
    func markCommissionsAsSettled(commissionIds: [String], settlementId: String) async

    /// Gets total unsettled commission amount for a trader
    func getTotalUnsettledCommission(for traderId: String) -> Double

    /// Gets total unsettled commission amount for an investor
    func getTotalUnsettledCommission(forInvestor investorId: String) -> Double
}

// MARK: - Commission Accumulation Service Implementation

final class CommissionAccumulationService: CommissionAccumulationServiceProtocol, ObservableObject {

    // MARK: - Properties

    @Published private var accumulations: [CommissionAccumulation] = []
    private let queue = DispatchQueue(label: "com.fin.app.commissionaccumulation", attributes: .concurrent)

    // MARK: - ServiceLifecycle

    func start() async {
        print("💰 CommissionAccumulationService started")
    }

    func stop() async {
        print("💰 CommissionAccumulationService stopped")
    }

    func reset() async {
        await MainActor.run {
            accumulations.removeAll()
        }
        print("💰 CommissionAccumulationService reset - all accumulations cleared")
    }

    // MARK: - Public Methods

    func recordCommission(
        investorId: String,
        traderId: String,
        tradeId: String,
        tradeNumber: Int,
        commissionAmount: Double,
        grossProfit: Double
    ) async {
        guard commissionAmount > 0 else {
            print("💰 CommissionAccumulationService: Commission amount is 0 or negative, skipping record")
            return
        }

        let accumulation = CommissionAccumulation(
            investorId: investorId,
            traderId: traderId,
            tradeId: tradeId,
            tradeNumber: tradeNumber,
            commissionAmount: commissionAmount,
            grossProfit: grossProfit
        )

        await MainActor.run {
            accumulations.append(accumulation)
        }

        print("💰 CommissionAccumulationService: Recorded commission accumulation")
        print("   👤 Investor ID: \(investorId)")
        print("   👤 Trader ID: \(traderId)")
        print("   📊 Trade ID: \(tradeId) (#\(tradeNumber))")
        print("   💰 Commission: €\(commissionAmount.formatted(.currency(code: "EUR")))")
    }

    func getUnsettledCommissions(for traderId: String) -> [CommissionAccumulation] {
        return queue.sync {
            return accumulations.filter { $0.traderId == traderId && !$0.isSettled }
        }
    }

    func getUnsettledCommissions(forInvestor investorId: String) -> [CommissionAccumulation] {
        return queue.sync {
            return accumulations.filter { $0.investorId == investorId && !$0.isSettled }
        }
    }

    func getUnsettledCommissionsByTrader() -> [String: [CommissionAccumulation]] {
        return queue.sync {
            let unsettled = accumulations.filter { !$0.isSettled }
            return Dictionary(grouping: unsettled, by: { $0.traderId })
        }
    }

    func getUnsettledCommissionsByInvestor() -> [String: [CommissionAccumulation]] {
        return queue.sync {
            let unsettled = accumulations.filter { !$0.isSettled }
            return Dictionary(grouping: unsettled, by: { $0.investorId })
        }
    }

    func markCommissionsAsSettled(commissionIds: [String], settlementId: String) async {
        await MainActor.run {
            for id in commissionIds {
                if let index = accumulations.firstIndex(where: { $0.id == id }) {
                    let existing = accumulations[index]
                    let updated = CommissionAccumulation(
                        id: existing.id,
                        investorId: existing.investorId,
                        traderId: existing.traderId,
                        tradeId: existing.tradeId,
                        tradeNumber: existing.tradeNumber,
                        commissionAmount: existing.commissionAmount,
                        grossProfit: existing.grossProfit,
                        createdAt: existing.createdAt,
                        settledAt: Date(),
                        settlementId: settlementId
                    )
                    accumulations[index] = updated
                }
            }
        }

        print("💰 CommissionAccumulationService: Marked \(commissionIds.count) commissions as settled")
        print("   📋 Settlement ID: \(settlementId)")
    }

    func getTotalUnsettledCommission(for traderId: String) -> Double {
        return queue.sync {
            return accumulations
                .filter { $0.traderId == traderId && !$0.isSettled }
                .reduce(0.0) { $0 + $1.commissionAmount }
        }
    }

    func getTotalUnsettledCommission(forInvestor investorId: String) -> Double {
        return queue.sync {
            return accumulations
                .filter { $0.investorId == investorId && !$0.isSettled }
                .reduce(0.0) { $0 + $1.commissionAmount }
        }
    }
}











