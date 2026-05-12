import Foundation

// MARK: - Investment API Service Protocol

/// Protocol for syncing investments to Parse Server backend.
/// Conformers must be safe to share across actor boundaries (`Sendable`) — the
/// stateless default implementation `InvestmentAPIService` marks itself
/// `@unchecked Sendable` because it holds only an immutable reference to a
/// `ParseAPIClientProtocol`.
protocol InvestmentAPIServiceProtocol: Sendable {
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

    /// Server-side cancel of a reserved split; releases escrow and credits wallet (see Cloud Code).
    func cancelReservedInvestment(investmentId: String) async throws

    /// Server-side activation of a reserved split by trader; triggers escrow RSV->TRD and accounting side effects.
    func activateReservedInvestment(investmentId: String) async throws

    /// ADR-007 Phase 2: idempotently creates the App-Service-Charge `Invoice` on the server.
    /// Returns the resulting invoice id (either newly created or the pre-existing idempotency hit).
    /// The server-side `afterSave Invoice` trigger books the BankContra and AppLedger entries.
    /// Safe to retry — the function short-circuits on (batchId, invoiceType='service_charge').
    func bookAppServiceCharge(investmentId: String) async throws -> String
}

// Note: PoolTradeParticipation is defined in FIN1/Features/Investor/Models/PoolTradeParticipation.swift

// MARK: - Parse Investment Model

/// Decodes a Parse date field that may arrive as an ISO string or as `{"__type":"Date","iso":"…"}`
struct FlexibleParseDate: Codable, Sendable {
    let dateString: String?

    init(dateString: String?) {
        self.dateString = dateString
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            dateString = nil
        } else if let str = try? container.decode(String.self) {
            dateString = str
        } else if let dict = try? container.decode([String: String].self), let iso = dict["iso"] {
            dateString = iso
        } else {
            dateString = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(dateString)
    }

    func toDate() -> Date? {
        guard let dateString else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: dateString) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: dateString)
    }
}

/// Parse Server representation of an Investment
struct ParseInvestment: Codable, Sendable {
    let objectId: String
    let investorId: String
    let investorName: String?
    let traderId: String
    let traderName: String?
    let amount: Double
    let currentValue: Double?
    let status: String
    let performance: Double?
    let numberOfTrades: Int?
    let batchId: String?
    let sequenceNumber: Int?
    let createdAt: FlexibleParseDate
    let updatedAt: FlexibleParseDate
    let completedAt: FlexibleParseDate?
    let activatedAt: FlexibleParseDate?
    let specialization: String?
    let reservationStatus: String?
    let profit: Double?
    let profitPercentage: Double?
    let investmentNumber: String?
    let partialSellCount: Int?
    let realizedSellQuantity: Double?
    let realizedSellAmount: Double?
    let lastPartialSellAt: FlexibleParseDate?
    let tradeSellVolumeProgress: Double?

    func toInvestment() -> Investment {
        let createdDate = createdAt.toDate() ?? Date()
        let updatedDate = updatedAt.toDate() ?? Date()
        let completedDate = completedAt?.toDate()
        let investmentStatus = InvestmentStatus(rawValue: status) ?? .active
        let reservStatus = InvestmentReservationStatus(rawValue: reservationStatus ?? status) ?? .active

        return Investment(
            id: objectId,
            investmentNumber: investmentNumber,
            batchId: batchId,
            investorId: investorId,
            investorName: investorName ?? "",
            traderId: traderId,
            traderName: traderName ?? "",
            amount: amount,
            currentValue: currentValue ?? amount,
            date: createdDate,
            status: investmentStatus,
            performance: profitPercentage ?? performance ?? 0.0,
            numberOfTrades: numberOfTrades ?? 0,
            sequenceNumber: sequenceNumber,
            createdAt: createdDate,
            updatedAt: updatedDate,
            completedAt: completedDate,
            specialization: specialization ?? "General",
            reservationStatus: reservStatus,
            partialSellCount: partialSellCount ?? 0,
            realizedSellQuantity: realizedSellQuantity ?? 0,
            realizedSellAmount: realizedSellAmount ?? 0,
            lastPartialSellAt: lastPartialSellAt?.toDate(),
            tradeSellVolumeProgress: tradeSellVolumeProgress
        )
    }
}

// MARK: - Parse Investment Input

private struct ParseInvestmentInput: Codable {
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

private struct CancelReservedInvestmentResponse: Decodable {
    let success: Bool?
}

private struct ActivateReservedInvestmentResponse: Decodable {
    let success: Bool?
    let investmentId: String?
    let status: String?
}

private struct ParsePoolParticipationInput: Codable {
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

private struct ParsePoolParticipationResponse: Decodable {
    let objectId: String
    let investmentId: String
    let tradeId: String
    let poolReservationId: String?
    let poolNumber: Int?
    let allocatedAmount: Double?
    let totalTradeValue: Double?
    let ownershipPercentage: Double?
    let profitShare: Double?
    let createdAt: FlexibleParseDate?
    let updatedAt: FlexibleParseDate?

    func toModel(fallback: PoolTradeParticipation) -> PoolTradeParticipation {
        let rawOwnership = ownershipPercentage ?? fallback.ownershipPercentage
        let normalizedOwnership = rawOwnership > 1.0 ? rawOwnership / 100.0 : rawOwnership

        return PoolTradeParticipation(
            id: objectId,
            tradeId: tradeId,
            investmentId: investmentId,
            poolReservationId: poolReservationId ?? fallback.poolReservationId,
            poolNumber: poolNumber ?? fallback.poolNumber,
            allocatedAmount: allocatedAmount ?? fallback.allocatedAmount,
            totalTradeValue: totalTradeValue ?? fallback.totalTradeValue,
            ownershipPercentage: normalizedOwnership,
            profitShare: profitShare ?? fallback.profitShare,
            createdAt: createdAt?.toDate() ?? fallback.createdAt,
            updatedAt: updatedAt?.toDate() ?? Date()
        )
    }
}

// MARK: - Investment API Service Implementation

final class InvestmentAPIService: InvestmentAPIServiceProtocol, @unchecked Sendable {

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
            investmentNumber: investment.investmentNumber,
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
            reservationStatus: investment.reservationStatus,
            partialSellCount: investment.partialSellCount,
            realizedSellQuantity: investment.realizedSellQuantity,
            realizedSellAmount: investment.realizedSellAmount,
            lastPartialSellAt: investment.lastPartialSellAt,
            tradeSellVolumeProgress: investment.tradeSellVolumeProgress
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
        let response: ParsePoolParticipationResponse = try await apiClient.callFunction(
            "recordPoolTradeParticipation",
            parameters: [
                "tradeId": participation.tradeId,
                "investmentId": participation.investmentId,
                "poolReservationId": participation.poolReservationId,
                "poolNumber": participation.poolNumber,
                "allocatedAmount": participation.allocatedAmount,
                "totalTradeValue": participation.totalTradeValue,
                "ownershipPercentage": participation.ownershipPercentage,
                "profitShare": participation.profitShare as Any
            ]
        )
        print("✅ InvestmentAPIService: Pool participation recorded via cloud function")
        return response.toModel(fallback: participation)
    }

    func updatePoolParticipation(_ participation: PoolTradeParticipation) async throws -> PoolTradeParticipation {
        print("📡 InvestmentAPIService: Updating pool participation \(participation.id)")
        let response: ParsePoolParticipationResponse = try await apiClient.callFunction(
            "updatePoolTradeParticipation",
            parameters: [
                "participationId": participation.id,
                "poolReservationId": participation.poolReservationId,
                "poolNumber": participation.poolNumber,
                "allocatedAmount": participation.allocatedAmount,
                "totalTradeValue": participation.totalTradeValue,
                "ownershipPercentage": participation.ownershipPercentage,
                "profitShare": participation.profitShare as Any
            ]
        )
        print("✅ InvestmentAPIService: Pool participation updated via cloud function")
        return response.toModel(fallback: participation)
    }

    func cancelReservedInvestment(investmentId: String) async throws {
        let _: CancelReservedInvestmentResponse = try await apiClient.callFunction(
            "cancelReservedInvestment",
            parameters: ["investmentId": investmentId]
        )
        print("✅ InvestmentAPIService: cancelReservedInvestment OK \(investmentId)")
    }

    func activateReservedInvestment(investmentId: String) async throws {
        let _: ActivateReservedInvestmentResponse = try await apiClient.callFunction(
            "traderActivateReservedInvestment",
            parameters: ["investmentId": investmentId]
        )
        print("✅ InvestmentAPIService: traderActivateReservedInvestment OK \(investmentId)")
    }

    func bookAppServiceCharge(investmentId: String) async throws -> String {
        let response: BookAppServiceChargeResponse = try await apiClient.callFunction(
            "bookAppServiceCharge",
            parameters: ["investmentId": investmentId]
        )
        if response.skipped == true {
            print("✅ InvestmentAPIService: bookAppServiceCharge — already booked (\(response.invoiceId))")
        } else {
            print("✅ InvestmentAPIService: bookAppServiceCharge — created invoice \(response.invoiceId)")
        }
        return response.invoiceId
    }
}

/// Response contract of the `bookAppServiceCharge` Cloud function.
/// See `backend/parse-server/cloud/functions/investment.js` (ADR-007 Phase 2).
private struct BookAppServiceChargeResponse: Decodable {
    let success: Bool
    let invoiceId: String
    let skipped: Bool?
    let reason: String?
}
