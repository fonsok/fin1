import Foundation

// MARK: - Investor Watchlist API Service Protocol

/// Protocol for syncing investor watchlist (traders) to Parse Server backend
protocol InvestorWatchlistAPIServiceProtocol {
    /// Saves a trader to the investor watchlist on Parse Server
    func saveWatchlistItem(_ trader: WatchlistTraderData, investorId: String) async throws -> WatchlistTraderData

    /// Removes a trader from the investor watchlist on Parse Server
    func removeWatchlistItem(_ traderId: String, investorId: String) async throws

    /// Fetches all watchlist items (traders) for an investor
    func fetchWatchlist(for investorId: String) async throws -> [WatchlistTraderData]
}

// MARK: - Parse Investor Watchlist Input

/// Input struct for creating investor watchlist items on Parse Server
private struct ParseInvestorWatchlistInput: Encodable {
    let investorId: String
    let traderId: String
    let traderName: String
    let traderSpecialization: String?
    let traderRiskClass: Int?
    let notes: String?
    let targetInvestmentAmount: Double?
    let notifyOnNewTrade: Bool
    let notifyOnPerformanceChange: Bool
    let sortOrder: Int

    static func from(trader: WatchlistTraderData, investorId: String) -> ParseInvestorWatchlistInput {
        return ParseInvestorWatchlistInput(
            investorId: investorId,
            traderId: trader.id,
            traderName: trader.name,
            traderSpecialization: nil, // Could be extracted from trader data if available
            traderRiskClass: trader.riskClass.rawValue,
            notes: nil,
            targetInvestmentAmount: nil,
            notifyOnNewTrade: trader.notificationsEnabled,
            notifyOnPerformanceChange: trader.notificationsEnabled,
            sortOrder: 0
        )
    }
}

// MARK: - Parse Investor Watchlist Response

/// Response struct for Parse Server investor watchlist operations
private struct ParseInvestorWatchlistResponse: Codable {
    let objectId: String
    let investorId: String
    let traderId: String
    let traderName: String
    let traderSpecialization: String?
    let traderRiskClass: Int?
    let notes: String?
    let targetInvestmentAmount: Double?
    let notifyOnNewTrade: Bool
    let notifyOnPerformanceChange: Bool
    let sortOrder: Int
    let addedAt: String

    func toWatchlistTraderData() throws -> WatchlistTraderData {
        let dateFormatter = ISO8601DateFormatter()
        let addedDate = dateFormatter.date(from: addedAt) ?? Date()

        // Note: We need to reconstruct WatchlistTraderData from minimal backend data
        // Some fields might need to be fetched from TraderDataService
        // For now, we'll use defaults for missing fields
        return WatchlistTraderData(
            id: traderId,
            name: traderName,
            image: "", // Will need to be fetched separately
            performance: 0.0, // Will need to be fetched separately
            riskClass: RiskClass(rawValue: traderRiskClass ?? 1) ?? .riskClass1,
            totalInvestors: 0, // Will need to be fetched separately
            minimumInvestment: targetInvestmentAmount ?? 0.0,
            description: "", // Will need to be fetched separately
            tradingStrategy: traderSpecialization ?? "", // Using specialization as strategy
            experience: "", // Will need to be fetched separately
            dateAdded: addedDate,
            lastUpdated: addedDate,
            isActive: true,
            notificationsEnabled: notifyOnNewTrade || notifyOnPerformanceChange
        )
    }
}

// MARK: - Investor Watchlist API Service Implementation

final class InvestorWatchlistAPIService: InvestorWatchlistAPIServiceProtocol {
    private let apiClient: ParseAPIClientProtocol
    private let className = "InvestorWatchlist"

    init(apiClient: ParseAPIClientProtocol) {
        self.apiClient = apiClient
    }

    func saveWatchlistItem(_ trader: WatchlistTraderData, investorId: String) async throws -> WatchlistTraderData {
        let input = ParseInvestorWatchlistInput.from(trader: trader, investorId: investorId)
        let _: ParseResponse = try await apiClient.createObject(
            className: className,
            object: input
        )

        // Return trader (backend doesn't change trader data, just stores reference)
        return trader
    }

    func removeWatchlistItem(_ traderId: String, investorId: String) async throws {
        // Find watchlist item by investorId and traderId
        let query: [String: Any] = [
            "investorId": investorId,
            "traderId": traderId
        ]

        let responses: [ParseInvestorWatchlistResponse] = try await apiClient.fetchObjects(
            className: className,
            query: query,
            include: nil,
            orderBy: nil,
            limit: nil
        )

        // Delete all matching items (should be unique)
        for response in responses {
            try await apiClient.deleteObject(className: className, objectId: response.objectId)
        }
    }

    func fetchWatchlist(for investorId: String) async throws -> [WatchlistTraderData] {
        let query: [String: Any] = [
            "investorId": investorId
        ]

        let responses: [ParseInvestorWatchlistResponse] = try await apiClient.fetchObjects(
            className: className,
            query: query,
            include: nil,
            orderBy: nil,
            limit: nil
        )

        return try responses.compactMap { response in
            try? response.toWatchlistTraderData()
        }
    }

}

// MARK: - Investor Watchlist API Service Error

enum InvestorWatchlistAPIServiceError: LocalizedError {
    case invalidData

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid watchlist data"
        }
    }
}
