import Foundation

/// Resolves investment return percentages strictly from backend-provided return metadata.
/// No client-side return formula is applied here.
enum ServerCalculatedReturnResolver {
    /// Returns backend-authoritative return percentage, or nil when backend data is unavailable/incomplete.
    static func resolveReturnPercentage(
        investmentId: String,
        settlementAPIService: (any SettlementAPIServiceProtocol)?
    ) async -> Double? {
        guard let settlementAPIService else { return nil }

        do {
            let response = try await settlementAPIService.fetchInvestorCollectionBills(
                limit: 500,
                skip: 0,
                investmentId: investmentId,
                tradeId: nil
            )

            guard !response.collectionBills.isEmpty else {
                return nil
            }

            var weightedReturnSum = 0.0
            var totalInvestedAmount = 0.0
            var missingReturnPercentageCount = 0

            for bill in response.collectionBills {
                guard let metadata = bill.metadata else { continue }
                guard let returnPercentage = metadata.returnPercentage else {
                    missingReturnPercentageCount += 1
                    continue
                }

                let buyAmount = metadata.buyLeg?.amount ?? 0.0
                let buyFees = metadata.buyLeg?.fees?.totalFees ?? 0.0
                let invested = buyAmount + buyFees
                guard invested > 0 else { continue }

                weightedReturnSum += returnPercentage * invested
                totalInvestedAmount += invested
            }

            #if DEBUG
            if missingReturnPercentageCount > 0 {
                assertionFailure("ServerCalculatedReturnResolver: \(missingReturnPercentageCount) collection bill(s) missing metadata.returnPercentage")
            }
            #endif

            guard totalInvestedAmount > 0 else { return nil }
            return weightedReturnSum / totalInvestedAmount
        } catch {
            print("⚠️ ServerCalculatedReturnResolver: Backend return fetch failed for investment \(investmentId): \(error.localizedDescription)")
            return nil
        }
    }
}
