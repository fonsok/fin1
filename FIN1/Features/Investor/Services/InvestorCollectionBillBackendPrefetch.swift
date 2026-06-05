import Foundation

// MARK: - Backend prefetch (one round-trip per investment)

/// Loads all investor collection bills for an investment in a single API call.
@MainActor
enum InvestorCollectionBillBackendPrefetch {

    static let defaultFetchLimit = 100

    static func loadBills(
        investmentId: String,
        settlementAPIService: any SettlementAPIServiceProtocol,
        limit: Int = defaultFetchLimit
    ) async throws -> [String: BackendCollectionBill] {
        let response = try await settlementAPIService.fetchInvestorCollectionBills(
            limit: limit,
            skip: 0,
            investmentId: investmentId,
            tradeId: nil
        )
        let index = InvestorCollectionBillBackendIndex.billsByTradeId(response.collectionBills)
        InvestorCollectionBillLog.debug(
            "prefetch investment=\(investmentId) bills=\(response.collectionBills.count) trades=\(index.count)"
        )
        return index
    }
}
