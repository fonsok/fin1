import Foundation

// MARK: - discoverTraders (Parse Cloud)

/// Loads trader catalog rows from `discoverTraders` (hydration + Discover-only traders).
struct TraderDiscoveryAPIService: Sendable {
    private let apiClient: any ParseAPIClientProtocol

    init(apiClient: any ParseAPIClientProtocol) {
        self.apiClient = apiClient
    }

    /// Username (lowercased) → Parse `objectId`.
    func fetchUsernameToParseIdMap(pageSize: Int = 100) async throws -> [String: String] {
        let rows = try await fetchAllDiscoverableTraders(pageSize: pageSize)
        var map: [String: String] = [:]
        for row in rows {
            guard let username = row.username?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  !username.isEmpty,
                  !row.traderId.isEmpty else { continue }
            map[username] = row.traderId
        }
        return map
    }

    /// Paginates `discoverTraders` until a short page is returned.
    func fetchAllDiscoverableTraders(pageSize: Int = 100) async throws -> [DiscoverTraderRecord] {
        var all: [DiscoverTraderRecord] = []
        var skip = 0
        let limit = max(1, min(pageSize, 100))
        while true {
            let page = try await fetchDiscoverableTradersPage(limit: limit, skip: skip)
            all.append(contentsOf: page)
            if page.count < limit { break }
            skip += limit
        }
        return all
    }

    private func fetchDiscoverableTradersPage(limit: Int, skip: Int) async throws -> [DiscoverTraderRecord] {
        let response: DiscoverTradersResponse = try await apiClient.callFunction(
            "discoverTraders",
            parameters: ["limit": limit, "skip": skip]
        )
        return response.traders.map { row in
            DiscoverTraderRecord(
                traderId: row.traderId,
                username: row.username,
                displayName: row.displayName,
                riskClass: row.riskClass,
                investorCount: row.investorCount,
                totalAUM: row.totalAUM,
                acceptingInvestments: row.acceptingInvestments
            )
        }
    }
}

private struct DiscoverTradersResponse: Decodable {
    let traders: [DiscoverTraderRow]
    let total: Int?
}

private struct DiscoverTraderRow: Decodable {
    let traderId: String
    let username: String?
    let displayName: String?
    let riskClass: Int?
    let investorCount: Int?
    let totalAUM: Double?
    let acceptingInvestments: Bool?
}
