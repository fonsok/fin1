import Foundation

// MARK: - discoverTraders row (client SSOT)

struct DiscoverTraderRecord: Equatable, Sendable {
    let traderId: String
    let username: String?
    let displayName: String?
    let riskClass: Int?
    let investorCount: Int?
    let totalAUM: Double?
    let acceptingInvestments: Bool?
}

// MARK: - Catalog merge (mock dashboard + discover)

/// Merges `discoverTraders` into the mock seed catalog without dropping demo metrics on the dashboard path.
enum TraderCatalogMerge {
    static let mockCatalogUsernameKeys: Set<String> = Set(mockTraders.map { $0.username.lowercased() })

    /// Mock seed rows (hydrated, stable order) plus server-only traders appended for Discover.
    static func merge(mockCatalog: [MockTrader], serverRows: [DiscoverTraderRecord]) -> [InvestorTrader] {
        let serverByUsername = Self.indexServerRowsByUsername(serverRows)
        var merged: [InvestorTrader] = []
        var consumedParseIds = Set<String>()

        for mock in mockCatalog {
            let key = mock.username.lowercased()
            if let row = serverByUsername[key] {
                merged.append(Self.applyServerHydration(to: mock, row: row))
                consumedParseIds.insert(row.traderId)
            } else {
                merged.append(InvestorTrader(mock: mock, isFromMockCatalog: true))
            }
        }

        for row in serverRows {
            guard !row.traderId.isEmpty, !consumedParseIds.contains(row.traderId) else { continue }
            let usernameKey = row.username?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            if !usernameKey.isEmpty, Self.mockCatalogUsernameKeys.contains(usernameKey) { continue }
            merged.append(Self.syntheticTrader(from: row))
            consumedParseIds.insert(row.traderId)
        }

        return merged
    }

    static func isMockCatalogTrader(_ trader: InvestorTrader) -> Bool {
        trader.isFromMockCatalog
    }

    // MARK: - Private

    private static func indexServerRowsByUsername(_ rows: [DiscoverTraderRecord]) -> [String: DiscoverTraderRecord] {
        var map: [String: DiscoverTraderRecord] = [:]
        for row in rows {
            guard let username = row.username?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  !username.isEmpty else { continue }
            map[username] = row
        }
        return map
    }

    private static func applyServerHydration(to mock: MockTrader, row: DiscoverTraderRecord) -> InvestorTrader {
        let displayName = row.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (displayName?.isEmpty == false) ? displayName! : mock.name
        let riskLevel = Self.riskLevel(from: row.riskClass) ?? mock.riskLevel
        let investor = InvestorTrader(mock: mock, isFromMockCatalog: true)
        return InvestorTrader(
            catalogId: mock.id.uuidString,
            parseUserId: row.traderId,
            name: name,
            username: mock.username,
            specialization: mock.specialization,
            experienceYears: mock.experienceYears,
            isVerified: mock.isVerified,
            riskLevel: riskLevel,
            demoMetrics: investor.demoMetrics,
            isFromMockCatalog: true
        )
    }

    private static func syntheticTrader(from row: DiscoverTraderRecord) -> InvestorTrader {
        let username = row.username?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "trader-\(row.traderId)"
        let name = row.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? row.displayName!.trimmingCharacters(in: .whitespacesAndNewlines)
            : username
        return InvestorTrader(
            catalogId: row.traderId,
            parseUserId: row.traderId,
            name: name,
            username: username,
            specialization: "General",
            experienceYears: 0,
            isVerified: true,
            riskLevel: Self.riskLevel(from: row.riskClass) ?? .medium,
            demoMetrics: nil,
            isFromMockCatalog: false
        )
    }

    private static func riskLevel(from riskClass: Int?) -> TraderRiskLevel? {
        guard let riskClass else { return nil }
        switch riskClass {
        case ...2: return .low
        case 3...5: return .medium
        default: return .high
        }
    }
}
