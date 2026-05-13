import Foundation

// MARK: - Settlement API Service Protocol

/// Communicates with backend Cloud Functions for authoritative trade settlement data.
protocol SettlementAPIServiceProtocol: Sendable {
    /// Checks whether a trade has been settled by the backend.
    func isTradeSettledByBackend(tradeId: String) async -> Bool

    /// Fetches the full settlement for a trade (AccountStatement entries, documents, commissions).
    func fetchTradeSettlement(tradeId: String) async throws -> TradeSettlementResponse

    /// Fetches paginated account statement entries for the current user.
    func fetchAccountStatement(limit: Int, skip: Int, entryType: String?) async throws -> BackendAccountStatementResponse

    /// Fetches invoices for a specific trade from the backend.
    func fetchTradeInvoices(tradeId: String) async throws -> BackendInvoiceListResponse

    /// Fetches paginated invoices for the current user.
    func fetchUserInvoices(limit: Int, skip: Int, invoiceType: String?) async throws -> BackendInvoiceListResponse

    /// Fetches investor collection bill documents for the current user.
    func fetchInvestorCollectionBills(limit: Int, skip: Int, investmentId: String?, tradeId: String?) async throws -> BackendCollectionBillResponse
}

// MARK: - Response Models

struct TradeSettlementResponse: Decodable {
    let tradeId: String
    let tradeNumber: Int?
    let grossProfit: Double
    let totalFees: Double
    let netProfit: Double
    let status: String
    let isSettledByBackend: Bool
    let accountStatementEntries: [BackendAccountEntry]
    let documents: [BackendSettlementDocument]
    let commissions: [BackendSettlementCommission]
}

/// Backend-produced AccountStatement record (maps 1:1 to the Parse `AccountStatement` class).
struct BackendAccountEntry: Decodable, Identifiable {
    let objectId: String
    let userId: String
    let entryType: String
    let amount: Double
    let balanceBefore: Double
    let balanceAfter: Double
    let tradeId: String?
    let tradeNumber: Int?
    let investmentId: String?
    let investmentNumber: String?
    let businessReference: String?
    let description: String?
    let source: String?
    let referenceDocumentId: String?
    let referenceDocumentNumber: String?
    let createdAt: String?

    var id: String { self.objectId }

    /// Parses the ISO-8601 `createdAt` string returned by Parse `toJSON()`.
    var createdAtDate: Date? {
        guard let iso = createdAt else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: iso) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: iso)
    }

    enum CodingKeys: String, CodingKey {
        case objectId, userId, entryType, amount, balanceBefore, balanceAfter
        case tradeId, tradeNumber, investmentId, investmentNumber
        case businessReference, description, source, referenceDocumentId, referenceDocumentNumber, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.objectId = try c.decode(String.self, forKey: .objectId)
        self.userId = try c.decodeIfPresent(String.self, forKey: .userId) ?? ""
        self.entryType = try c.decodeIfPresent(String.self, forKey: .entryType) ?? ""
        self.amount = c.decodeLossyDouble(forKey: .amount) ?? 0
        self.balanceBefore = c.decodeLossyDouble(forKey: .balanceBefore) ?? 0
        self.balanceAfter = c.decodeLossyDouble(forKey: .balanceAfter) ?? 0
        self.tradeId = try c.decodeIfPresent(String.self, forKey: .tradeId)
        self.tradeNumber = c.decodeLossyInt(forKey: .tradeNumber)
        self.investmentId = try c.decodeIfPresent(String.self, forKey: .investmentId)
        self.investmentNumber = try c.decodeIfPresent(String.self, forKey: .investmentNumber)
        self.businessReference = try c.decodeIfPresent(String.self, forKey: .businessReference)
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.source = try c.decodeIfPresent(String.self, forKey: .source)
        self.referenceDocumentId = try c.decodeIfPresent(String.self, forKey: .referenceDocumentId)
        self.referenceDocumentNumber = try c.decodeIfPresent(String.self, forKey: .referenceDocumentNumber)
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

private extension KeyedDecodingContainer where K == BackendAccountEntry.CodingKeys {
    func decodeLossyInt(forKey key: K) -> Int? {
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }
        if let str = try? decode(String.self, forKey: key) {
            return Int(str)
        }
        if let dbl = try? decode(Double.self, forKey: key) {
            return Int(dbl)
        }
        return nil
    }

    func decodeLossyDouble(forKey key: K) -> Double? {
        if let value = try? decode(Double.self, forKey: key) {
            return value
        }
        if let intValue = try? decode(Int.self, forKey: key) {
            return Double(intValue)
        }
        if let str = try? decode(String.self, forKey: key),
           let parsed = Double(str) {
            return parsed
        }
        return nil
    }
}

/// Backend-produced Document record (maps 1:1 to the Parse `Document` class).
struct BackendSettlementDocument: Decodable, Identifiable {
    let objectId: String
    let userId: String
    let type: String
    let name: String
    let tradeId: String?
    let investmentId: String?
    let accountingDocumentNumber: String?
    let metadata: BackendDocumentMetadata?
    let source: String?

    var id: String { self.objectId }
}

struct BackendDocumentMetadata: Decodable {
    let commissionAmount: Double?
    let commissionRate: Double?
    let grossProfit: Double?
    let netProfit: Double?
    let ownershipPercentage: Double?
    let commission: Double?
}

struct BackendSettlementCommission: Decodable, Identifiable {
    let objectId: String
    let traderId: String?
    let investorId: String?
    let investmentId: String?
    let tradeId: String?
    let commissionRate: Double?
    let commissionAmount: Double?
    let investorGrossProfit: Double?
    let status: String?

    var id: String { self.objectId }
}

struct BackendAccountStatementResponse: Decodable {
    let entries: [BackendAccountEntry]
    let total: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey { case entries, total, hasMore }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.entries = try c.decodeIfPresent([BackendAccountEntry].self, forKey: .entries) ?? []
        self.total = try c.decodeIfPresent(Int.self, forKey: .total) ?? self.entries.count
        self.hasMore = try c.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
    }
}

// MARK: - Backend Invoice Models

struct BackendInvoiceLineItem: Decodable {
    let description: String?
    let quantity: Double?
    let unitPrice: Double?
    let itemType: String?
}

struct BackendInvoiceMetadata: Decodable {
    let investmentNumber: String?
    let serviceChargeRate: Double?
    let investorAccountType: String?
    let totalInvestmentAmount: Double?
}

struct BackendFeeBreakdown: Decodable {
    let orderFee: Double?
    let exchangeFee: Double?
    let foreignCosts: Double?
    let totalFees: Double?
}

struct BackendInvoice: Decodable, Identifiable {
    let objectId: String
    let invoiceNumber: String?
    let invoiceType: String?
    let userId: String?
    let tradeId: String?
    let orderId: String?
    let totalAmount: Double?
    let customerName: String?
    let customerAddress: String?
    let customerCity: String?
    let customerPostalCode: String?
    let customerId: String?
    /// `subtotal` is the canonical net amount on Parse `Invoice` (see backend `bookAppServiceCharge`).
    /// `netAmount` is the legacy alias retained for older records that pre-date the rename.
    let subtotal: Double?
    let netAmount: Double?
    let taxAmount: Double?
    let taxRate: Double?
    let status: String?
    let symbol: String?
    let side: String?
    let quantity: Double?
    let price: Double?
    let lineItems: [BackendInvoiceLineItem]?
    let feeBreakdown: BackendFeeBreakdown?
    let invoiceDate: DateValue?
    let source: String?
    let createdAt: String?
    let traderCommissionRateSnapshot: Double?
    /// Service-charge invoices store the calculation breakdown as text lines here (see `bookAppServiceCharge`).
    let investmentIds: [String]?
    let metadata: BackendInvoiceMetadata?

    var id: String { self.objectId }

    /// Represents Parse Server date values which can arrive as either a string or a `{ __type: "Date", iso: "..." }` object.
    enum DateValue: Decodable {
        case string(String)
        case parseDate(String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let str = try? container.decode(String.self) {
                self = .string(str)
                return
            }
            let obj = try ParseDateObject(from: decoder)
            self = .parseDate(obj.iso)
        }

        var isoString: String {
            switch self {
            case .string(let s): return s
            case .parseDate(let s): return s
            }
        }

        private struct ParseDateObject: Decodable {
            let iso: String
        }
    }

    var invoiceDateParsed: Date? {
        guard let iso = invoiceDate?.isoString else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: iso) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: iso)
    }
}

struct BackendInvoiceListResponse: Decodable {
    let invoices: [BackendInvoice]
    let count: Int?
    let total: Int?
    let hasMore: Bool?
}

// MARK: - Backend Collection Bill Models

struct BackendCollectionBillLeg: Decodable {
    let quantity: Double?
    let price: Double?
    let amount: Double?
    let fees: BackendFeeBreakdown?
    let residualAmount: Double?
}

struct BackendCollectionBillMetadata: Decodable {
    let ownershipPercentage: Double?
    let grossProfit: Double?
    let commission: Double?
    let netProfit: Double?
    let returnPercentage: Double?
    let commissionRate: Double?
    let buyLeg: BackendCollectionBillLeg?
    let sellLeg: BackendCollectionBillLeg?
}

struct BackendCollectionBill: Decodable, Identifiable {
    let objectId: String
    let userId: String?
    let type: String?
    let investmentId: String?
    let tradeId: String?
    let tradeNumber: Int?
    let accountingDocumentNumber: String?
    let source: String?
    let metadata: BackendCollectionBillMetadata?
    let createdAt: String?

    var id: String { self.objectId }
}

struct BackendCollectionBillResponse: Decodable {
    let collectionBills: [BackendCollectionBill]
    let total: Int?
    let hasMore: Bool?
}

// MARK: - Settlement API Service Implementation

final class SettlementAPIService: SettlementAPIServiceProtocol, @unchecked Sendable {

    private let apiClient: any ParseAPIClientProtocol

    init(apiClient: any ParseAPIClientProtocol) {
        self.apiClient = apiClient
    }

    func isTradeSettledByBackend(tradeId: String) async -> Bool {
        do {
            let response: TradeSettlementResponse = try await apiClient.callFunction(
                "getTradeSettlement",
                parameters: ["tradeId": tradeId]
            )
            return response.isSettledByBackend
        } catch {
            print("⚠️ SettlementAPIService: Failed to check settlement for trade \(tradeId): \(error.localizedDescription)")
            return false
        }
    }

    func fetchTradeSettlement(tradeId: String) async throws -> TradeSettlementResponse {
        try await self.apiClient.callFunction(
            "getTradeSettlement",
            parameters: ["tradeId": tradeId]
        )
    }

    func fetchAccountStatement(limit: Int = 50, skip: Int = 0, entryType: String? = nil) async throws -> BackendAccountStatementResponse {
        var params: [String: Any] = ["limit": limit, "skip": skip]
        if let entryType = entryType {
            params["entryType"] = entryType
        }
        return try await self.apiClient.callFunction(
            "getAccountStatement",
            parameters: params
        )
    }

    func fetchTradeInvoices(tradeId: String) async throws -> BackendInvoiceListResponse {
        try await self.apiClient.callFunction(
            "getTradeInvoices",
            parameters: ["tradeId": tradeId]
        )
    }

    func fetchUserInvoices(limit: Int = 50, skip: Int = 0, invoiceType: String? = nil) async throws -> BackendInvoiceListResponse {
        var params: [String: Any] = ["limit": limit, "skip": skip]
        if let invoiceType = invoiceType {
            params["invoiceType"] = invoiceType
        }
        return try await self.apiClient.callFunction(
            "getUserInvoices",
            parameters: params
        )
    }

    func fetchInvestorCollectionBills(limit: Int = 50, skip: Int = 0, investmentId: String? = nil, tradeId: String? = nil) async throws -> BackendCollectionBillResponse {
        var params: [String: Any] = ["limit": limit, "skip": skip]
        if let investmentId = investmentId { params["investmentId"] = investmentId }
        if let tradeId = tradeId { params["tradeId"] = tradeId }
        return try await self.apiClient.callFunction(
            "getInvestorCollectionBills",
            parameters: params
        )
    }
}
