import Foundation

// MARK: - Customer closing balance (matches Admin Portal / getAccountStatement merge)

enum InvestorCustomerClosingBalanceResolver {
    /// Paginates investor `getAccountStatement` and returns the last row's `balanceAfter`
    /// (same basis as Admin Portal „Kundensicht“).
    static func fetchClosingBalance(
        settlementAPIService: any SettlementAPIServiceProtocol
    ) async -> Double? {
        do {
            var allBackendEntries: [BackendAccountEntry] = []
            var skip = 0
            let pageSize = 200
            repeat {
                let response = try await settlementAPIService.fetchAccountStatement(
                    limit: pageSize,
                    skip: skip,
                    entryType: nil
                )
                allBackendEntries.append(contentsOf: response.entries)
                skip += response.entries.count
                if !response.hasMore || response.entries.isEmpty { break }
            } while skip < 2_000

            guard let last = allBackendEntries.last else { return nil }
            return last.balanceAfter
        } catch {
            print("⚠️ InvestorCustomerClosingBalanceResolver: fetch failed — \(error.localizedDescription)")
            return nil
        }
    }
}
