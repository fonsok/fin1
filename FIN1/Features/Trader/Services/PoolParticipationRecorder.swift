import Foundation

// MARK: - Pool Participation Recorder
/// Handles recording of pool participations for activated investments
/// Calculates securities value allocations and records them in the participation service
struct PoolParticipationRecorder {

    // MARK: - Types

    struct ParticipationSummary {
        let totalInvestors: Int
        let totalCapital: Double
        let totalSecuritiesValue: Double
        let traderSecuritiesValue: Double
        let totalTradeValue: Double
        let capitalUtilization: Double
        let unusedCapital: Double
    }

    // MARK: - Public API

    /// Records pool participations for activated investments
    /// - Parameters:
    ///   - activatedInvestments: Investments that were activated for this trade
    ///   - order: The order that triggered the activation
    ///   - trade: The trade being recorded
    ///   - poolTradeParticipationService: Service to record participations
    static func recordParticipations(
        activatedInvestments: [Investment],
        order: Order,
        trade: Trade,
        poolTradeParticipationService: any PoolTradeParticipationServiceProtocol
    ) async {
        guard !activatedInvestments.isEmpty else {
            print("⚠️ PoolParticipationRecorder: No investments were activated")
            return
        }

        // Collect pool entries
        let poolEntries = collectPoolEntries(from: activatedInvestments)
        print("🔍 PoolParticipationRecorder: Starting with \(poolEntries.count) entries")

        // Calculate securities values
        let totalPoolsCapital = poolEntries.reduce(0.0) { $0 + $1.capitalAmount }
        let totalOrderSecuritiesValue = order.totalAmount

        let totalInvestmentSecuritiesValue = SecuritiesValueCalculator.calculateMaxSecuritiesValue(
            fromCapital: totalPoolsCapital,
            pricePerSecurity: order.price,
            subscriptionRatio: order.subscriptionRatio ?? 1.0,
            denomination: order.denomination
        )

        let traderSecuritiesValue = max(totalOrderSecuritiesValue - totalInvestmentSecuritiesValue, 0.0)
        let totalTradeValue = traderSecuritiesValue + totalInvestmentSecuritiesValue

        // Log summary
        logParticipationSummary(
            poolEntries: poolEntries,
            totalPoolsCapital: totalPoolsCapital,
            totalOrderSecuritiesValue: totalOrderSecuritiesValue,
            totalInvestmentSecuritiesValue: totalInvestmentSecuritiesValue,
            traderSecuritiesValue: traderSecuritiesValue,
            totalTradeValue: totalTradeValue
        )

        // Allocate and record participations
        await allocateAndRecord(
            poolEntries: poolEntries,
            totalPoolsCapital: totalPoolsCapital,
            totalInvestmentSecuritiesValue: totalInvestmentSecuritiesValue,
            totalTradeValue: totalTradeValue,
            trade: trade,
            poolTradeParticipationService: poolTradeParticipationService
        )
    }

    // MARK: - Private Helpers

    private static func collectPoolEntries(from investments: [Investment]) -> [(investment: Investment, capitalAmount: Double)] {
        var entries: [(investment: Investment, capitalAmount: Double)] = []
        for inv in investments where inv.reservationStatus == .active {
            entries.append((inv, inv.amount))
            print("   📊 Investment \(inv.id): capital=€\(String(format: "%.2f", inv.amount)), status=\(inv.reservationStatus.rawValue)")
        }
        return entries
    }

    private static func logParticipationSummary(
        poolEntries: [(investment: Investment, capitalAmount: Double)],
        totalPoolsCapital: Double,
        totalOrderSecuritiesValue: Double,
        totalInvestmentSecuritiesValue: Double,
        traderSecuritiesValue: Double,
        totalTradeValue: Double
    ) {
        print("💰 PoolParticipationRecorder: Trade participation summary:")
        print("   📊 Total investors participating: \(poolEntries.count)")
        print("   💵 Total investment capital: €\(String(format: "%.2f", totalPoolsCapital))")
        print("   💵 Total order securities value: €\(String(format: "%.2f", totalOrderSecuritiesValue))")
        print("   💵 Investment securities value portion: €\(String(format: "%.2f", totalInvestmentSecuritiesValue))")
        print("   💵 Trader securities value share: €\(String(format: "%.2f", traderSecuritiesValue))")
        print("   💵 Total trade value (securities): €\(String(format: "%.2f", totalTradeValue))")

        // Capital utilization
        let investmentFees = FeeCalculationService.calculateTotalFees(for: totalInvestmentSecuritiesValue)
        let investmentTotalCost = totalInvestmentSecuritiesValue + investmentFees
        let capitalUtilization = totalPoolsCapital > 0 ? (investmentTotalCost / totalPoolsCapital) * 100.0 : 0.0
        let unusedCapital = max(0.0, totalPoolsCapital - investmentTotalCost)

        print("   📊 Capital utilization analysis:")
        print("      📈 Capital utilization: \(String(format: "%.2f", capitalUtilization))%")
        print("      💵 Unused capital: €\(String(format: "%.2f", unusedCapital))")

        if unusedCapital > 0.01 {
            print("      ⚠️ WARNING: \(String(format: "%.2f", unusedCapital)) capital is NOT being used!")
        } else {
            print("      ✅ Full capital utilization achieved")
        }
    }

    private static func allocateAndRecord(
        poolEntries: [(investment: Investment, capitalAmount: Double)],
        totalPoolsCapital: Double,
        totalInvestmentSecuritiesValue: Double,
        totalTradeValue: Double,
        trade: Trade,
        poolTradeParticipationService: any PoolTradeParticipationServiceProtocol
    ) async {
        print("   📝 Allocating securities value to individual investments:")
        var totalAllocatedSecuritiesValue = 0.0

        for entry in poolEntries {
            let investmentSecuritiesValue: Double
            if totalPoolsCapital > 0 {
                let capitalProportion = entry.capitalAmount / totalPoolsCapital
                investmentSecuritiesValue = capitalProportion * totalInvestmentSecuritiesValue

                print("      📊 Investment \(entry.investment.id):")
                print("         💵 Capital: €\(String(format: "%.2f", entry.capitalAmount))")
                print("         📊 Capital proportion: \(String(format: "%.4f", capitalProportion)) (\(String(format: "%.2f", capitalProportion * 100))%)")
                print("         💵 Securities value: €\(String(format: "%.2f", investmentSecuritiesValue))")

                totalAllocatedSecuritiesValue += investmentSecuritiesValue
            } else {
                investmentSecuritiesValue = 0.0
                print("      ⚠️ Investment \(entry.investment.id): totalPoolsCapital is 0")
            }

            await poolTradeParticipationService.recordPoolParticipation(
                tradeId: trade.id,
                investmentId: entry.investment.id,
                poolReservationId: entry.investment.id,
                poolNumber: entry.investment.sequenceNumber ?? 1,
                allocatedAmount: investmentSecuritiesValue,
                totalTradeValue: totalTradeValue
            )

            print("✅ PoolParticipationRecorder: Recorded participation for investment \(entry.investment.id)")
        }

        // Verify allocation
        let allocationDifference = abs(totalAllocatedSecuritiesValue - totalInvestmentSecuritiesValue)
        if allocationDifference > 0.01 {
            print("   ⚠️ WARNING: Allocation mismatch! Difference: €\(String(format: "%.2f", allocationDifference))")
        } else {
            print("   ✅ Allocation matches expected total")
        }
    }
}





