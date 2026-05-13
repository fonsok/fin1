import Foundation

/// Server-canonical aggregate over all investorCollectionBill documents for a given
/// investment. All amounts are summed across bills (an investment with partial-fill
/// trades can have multiple bills); `returnPercentage` is the weighted average by
/// invested amount (Total Buy Cost).
///
/// See Documentation/RETURN_CALCULATION_SCHEMAS.md and ADR-006 for the definitions.
struct ServerInvestmentCanonicalSummary: Equatable {
    let grossProfit: Double
    let commission: Double
    let netProfit: Double
    let totalBuyCost: Double
    /// ROI2 — weighted average of canonical `metadata.returnPercentage` values.
    let returnPercentage: Double
    /// True if at least one bill carried a canonical `returnPercentage`.
    let hasReturnPercentage: Bool
    let billCount: Int
}

/// Resolves investment return percentages strictly from backend-provided return metadata.
/// No client-side return formula is applied here.
enum ServerCalculatedReturnResolver {
    /// Aggregates `getInvestorCollectionBills` rows that carry canonical `metadata.returnPercentage`
    /// (settlement / Teil-Sell-Deltas). Same rules as `resolveCanonicalSummary` after fetch.
    static func canonicalSummary(fromCollectionBills bills: [BackendCollectionBill]) -> ServerInvestmentCanonicalSummary? {
        guard !bills.isEmpty else { return nil }

        var grossProfitSum = 0.0
        var commissionSum = 0.0
        var netProfitSum = 0.0
        var totalBuyCostSum = 0.0

        var weightedReturnSum = 0.0
        var totalInvestedAmount = 0.0
        var fallbackReturnSum = 0.0
        var fallbackReturnCount = 0
        var billCount = 0

        for bill in bills {
            guard let metadata = bill.metadata else { continue }
            guard let returnPercentage = metadata.returnPercentage else { continue }

            billCount += 1

            let grossProfit = metadata.grossProfit ?? 0.0
            let commission = metadata.commission ?? 0.0
            let netProfit = metadata.netProfit ?? (grossProfit - commission)
            grossProfitSum += grossProfit
            commissionSum += commission
            netProfitSum += netProfit

            let buyAmount = metadata.buyLeg?.amount ?? 0.0
            let buyFees = metadata.buyLeg?.fees?.totalFees ?? 0.0
            let investedFromLeg = buyAmount + buyFees
            let investedDerived = (investedFromLeg == 0 && returnPercentage != 0)
                ? netProfit / (returnPercentage / 100.0)
                : 0
            totalBuyCostSum += (investedFromLeg > 0 ? investedFromLeg : investedDerived)

            if investedFromLeg > 0 {
                weightedReturnSum += returnPercentage * investedFromLeg
                totalInvestedAmount += investedFromLeg
            } else {
                fallbackReturnSum += returnPercentage
                fallbackReturnCount += 1
            }
        }

        guard billCount > 0 else { return nil }

        let resolvedReturn: Double?
        if totalInvestedAmount > 0 {
            resolvedReturn = weightedReturnSum / totalInvestedAmount
        } else if fallbackReturnCount > 0 {
            resolvedReturn = fallbackReturnSum / Double(fallbackReturnCount)
        } else {
            resolvedReturn = nil
        }

        return ServerInvestmentCanonicalSummary(
            grossProfit: grossProfitSum,
            commission: commissionSum,
            netProfit: netProfitSum,
            totalBuyCost: totalBuyCostSum,
            returnPercentage: resolvedReturn ?? 0,
            hasReturnPercentage: resolvedReturn != nil,
            billCount: billCount
        )
    }

    /// Returns backend-authoritative return percentage (ROI2), or nil when backend data
    /// is unavailable/incomplete.
    static func resolveReturnPercentage(
        investmentId: String,
        settlementAPIService: (any SettlementAPIServiceProtocol)?
    ) async -> Double? {
        guard let summary = await resolveCanonicalSummary(
            investmentId: investmentId,
            settlementAPIService: settlementAPIService
        ) else {
            return nil
        }
        return summary.hasReturnPercentage ? summary.returnPercentage : nil
    }

    /// Aggregates the full canonical financial summary for an investment across all its
    /// server-side `investorCollectionBill` documents. Returns nil if the fetch fails
    /// or if the backend returned no settlement bills for this investment.
    ///
    /// Any documents without a canonical `metadata.returnPercentage` (e.g. legacy rows
    /// or wallet/activation receipts that somehow leak through the `type` filter) are
    /// silently skipped — they are not settlement bills and must not contribute to the
    /// ROI2 value shown to the investor.
    static func resolveCanonicalSummary(
        investmentId: String,
        settlementAPIService: (any SettlementAPIServiceProtocol)?
    ) async -> ServerInvestmentCanonicalSummary? {
        guard let settlementAPIService else { return nil }

        do {
            let response = try await settlementAPIService.fetchInvestorCollectionBills(
                limit: 500,
                skip: 0,
                investmentId: investmentId,
                tradeId: nil
            )
            return self.canonicalSummary(fromCollectionBills: response.collectionBills)
        } catch {
            print("⚠️ ServerCalculatedReturnResolver: Backend fetch failed for investment \(investmentId): \(error.localizedDescription)")
            return nil
        }
    }
}
