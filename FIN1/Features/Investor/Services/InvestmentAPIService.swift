import Foundation

// MARK: - Investment API Service Protocol

/// Protocol for syncing investments to Parse Server backend
protocol InvestmentAPIServiceProtocol {
    /// Saves an investment to the Parse Server
    func saveInvestment(_ investment: Investment) async throws -> Investment

    /// Updates an existing investment on the Parse Server
    func updateInvestment(_ investment: Investment) async throws -> Investment

    /// Fetches all investments for an investor
    func fetchInvestments(for investorId: String) async throws -> [Investment]

    /// Creates a pool trade participation record
    func createPoolParticipation(_ participation: PoolTradeParticipation) async throws -> PoolTradeParticipation

    /// Updates pool participation (e.g., when trade completes)
    func updatePoolParticipation(_ participation: PoolTradeParticipation) async throws -> PoolTradeParticipation
}

// Note: PoolTradeParticipation is defined in FIN1/Features/Investor/Models/PoolTradeParticipation.swift

// MARK: - Parse Investment Model

/// Parse Server representation of an Investment
struct ParseInvestment: Codable {
    let objectId: String
    let investorId: String
    let investorName: String
    let traderId: String
    let traderName: String
    let amount: Double
    let currentValue: Double
    let status: String
    let performance: Double
    let numberOfTrades: Int
    let batchId: String?
    let sequenceNumber: Int?
    let createdAt: String
    let updatedAt: String
    let completedAt: String?
    let specialization: String?
    let reservationStatus: String?

    func toInvestment() -> Investment {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let createdDate = dateFormatter.date(from: createdAt) ?? Date()
        let updatedDate = dateFormatter.date(from: updatedAt) ?? Date()
        let completedDate = completedAt.flatMap { dateFormatter.date(from: $0) }
        let investmentStatus = InvestmentStatus(rawValue: status) ?? .active
        let reservStatus = InvestmentReservationStatus(rawValue: reservationStatus ?? "active") ?? .active

        return Investment(
            id: objectId,
            batchId: batchId,
            investorId: investorId,
            investorName: investorName,
            traderId: traderId,
            traderName: traderName,
            amount: amount,
            currentValue: currentValue,
            date: createdDate,
            status: investmentStatus,
            performance: performance,
            numberOfTrades: numberOfTrades,
            sequenceNumber: sequenceNumber,
            createdAt: createdDate,
            updatedAt: updatedDate,
            completedAt: completedDate,
            specialization: specialization ?? "General",
            reservationStatus: reservStatus
        )
    }
}

// MARK: - Parse Investment Input

private struct ParseInvestmentInput: Encodable {
    let investorId: String
    let investorName: String
    let traderId: String
    let traderName: String
    let amount: Double
    let currentValue: Double
    let status: String
    let performance: Double
    let numberOfTrades: Int
    let batchId: String?
    let sequenceNumber: Int?
    let completedAt: String?
    let specialization: String
    let reservationStatus: String

    static func from(investment: Investment) -> ParseInvestmentInput {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return ParseInvestmentInput(
            investorId: investment.investorId,
            investorName: investment.investorName,
            traderId: investment.traderId,
            traderName: investment.traderName,
            amount: investment.amount,
            currentValue: investment.currentValue,
            status: investment.status.rawValue,
            performance: investment.performance,
            numberOfTrades: investment.numberOfTrades,
            batchId: investment.batchId,
            sequenceNumber: investment.sequenceNumber,
            completedAt: investment.completedAt.map { dateFormatter.string(from: $0) },
            specialization: investment.specialization,
            reservationStatus: investment.reservationStatus.rawValue
        )
    }
}

// MARK: - Parse Pool Participation Input
// Maps local PoolTradeParticipation to Parse Server format

private struct ParsePoolParticipationInput: Encodable {
    let investmentId: String
    let tradeId: String
    let poolReservationId: String
    let poolNumber: Int
    let allocatedAmount: Double
    let totalTradeValue: Double
    let ownershipPercentage: Double
    let profitShare: Double?
    let isSettled: Bool

    static func from(participation: PoolTradeParticipation, investorId: String? = nil, traderId: String? = nil) -> ParsePoolParticipationInput {
        return ParsePoolParticipationInput(
            investmentId: participation.investmentId,
            tradeId: participation.tradeId,
            poolReservationId: participation.poolReservationId,
            poolNumber: participation.poolNumber,
            allocatedAmount: participation.allocatedAmount,
            totalTradeValue: participation.totalTradeValue,
            ownershipPercentage: participation.ownershipPercentage,
            profitShare: participation.profitShare,
            isSettled: participation.profitShare != nil
        )
    }
}

// MARK: - Investment API Service Implementation

final class InvestmentAPIService: InvestmentAPIServiceProtocol {

    private let apiClient: ParseAPIClientProtocol
    private let investmentClassName = "Investment"
    private let participationClassName = "PoolTradeParticipation"

    init(apiClient: ParseAPIClientProtocol) {
        self.apiClient = apiClient
    }

    // MARK: - Investment Methods

    func saveInvestment(_ investment: Investment) async throws -> Investment {
        print("📡 InvestmentAPIService: Saving investment to Parse Server")

        let parseInput = ParseInvestmentInput.from(investment: investment)

        let response = try await apiClient.createObject(
            className: investmentClassName,
            object: parseInput
        )

        print("✅ InvestmentAPIService: Investment saved with objectId: \(response.objectId)")

        // Return investment with Parse objectId
        return Investment(
            id: response.objectId,
            batchId: investment.batchId,
            investorId: investment.investorId,
            investorName: investment.investorName,
            traderId: investment.traderId,
            traderName: investment.traderName,
            amount: investment.amount,
            currentValue: investment.currentValue,
            date: investment.date,
            status: investment.status,
            performance: investment.performance,
            numberOfTrades: investment.numberOfTrades,
            sequenceNumber: investment.sequenceNumber,
            createdAt: investment.createdAt,
            updatedAt: investment.updatedAt,
            completedAt: investment.completedAt,
            specialization: investment.specialization,
            reservationStatus: investment.reservationStatus
        )
    }

    func updateInvestment(_ investment: Investment) async throws -> Investment {
        print("📡 InvestmentAPIService: Updating investment \(investment.id) on Parse Server")

        let parseInput = ParseInvestmentInput.from(investment: investment)

        _ = try await apiClient.updateObject(
            className: investmentClassName,
            objectId: investment.id,
            object: parseInput
        )

        print("✅ InvestmentAPIService: Investment updated successfully")
        return investment
    }

    func fetchInvestments(for investorId: String) async throws -> [Investment] {
        print("📡 InvestmentAPIService: Fetching investments for investor \(investorId)")

        let query: [String: Any] = ["investorId": investorId]

        let parseInvestments: [ParseInvestment] = try await apiClient.fetchObjects(
            className: investmentClassName,
            query: query,
            include: nil,
            orderBy: "-createdAt",
            limit: 1000
        )

        print("📡 InvestmentAPIService: Fetched \(parseInvestments.count) investments")

        return parseInvestments.map { $0.toInvestment() }
    }

    // MARK: - Pool Participation Methods

    func createPoolParticipation(_ participation: PoolTradeParticipation) async throws -> PoolTradeParticipation {
        print("📡 InvestmentAPIService: Creating pool participation for trade \(participation.tradeId)")

        let parseInput = ParsePoolParticipationInput.from(participation: participation)

        let response = try await apiClient.createObject(
            className: participationClassName,
            object: parseInput
        )

        print("✅ InvestmentAPIService: Pool participation created with objectId: \(response.objectId)")

        // Return updated participation with server ID
        return PoolTradeParticipation(
            id: response.objectId,
            tradeId: participation.tradeId,
            investmentId: participation.investmentId,
            poolReservationId: participation.poolReservationId,
            poolNumber: participation.poolNumber,
            allocatedAmount: participation.allocatedAmount,
            totalTradeValue: participation.totalTradeValue,
            ownershipPercentage: participation.ownershipPercentage,
            profitShare: participation.profitShare,
            createdAt: participation.createdAt,
            updatedAt: Date()
        )
    }

    func updatePoolParticipation(_ participation: PoolTradeParticipation) async throws -> PoolTradeParticipation {
        print("📡 InvestmentAPIService: Updating pool participation \(participation.id)")

        let parseInput = ParsePoolParticipationInput.from(participation: participation)

        _ = try await apiClient.updateObject(
            className: participationClassName,
            objectId: participation.id,
            object: parseInput
        )

        print("✅ InvestmentAPIService: Pool participation updated successfully")
        return participation
    }
}
