import Foundation

// MARK: - Settlement API Service Protocol

/// Communicates with backend Cloud Functions for authoritative trade settlement data.
protocol SettlementAPIServiceProtocol {
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
    let description: String?
    let source: String?
    let referenceDocumentId: String?
    let createdAt: String?

    var id: String { objectId }

    /// Parses the ISO-8601 `createdAt` string returned by Parse `toJSON()`.
    var createdAtDate: Date? {
        guard let iso = createdAt else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: iso) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: iso)
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

    var id: String { objectId }
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
    let status: String?

    var id: String { objectId }
}

struct BackendAccountStatementResponse: Decodable {
    let entries: [BackendAccountEntry]
    let total: Int
    let hasMore: Bool
}

// MARK: - Backend Invoice Models

struct BackendInvoiceLineItem: Decodable {
    let description: String?
    let quantity: Double?
    let unitPrice: Double?
    let itemType: String?
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
    let netAmount: Double?
    let taxAmount: Double?
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

    var id: String { objectId }

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

    var id: String { objectId }
}

struct BackendCollectionBillResponse: Decodable {
    let collectionBills: [BackendCollectionBill]
    let total: Int?
    let hasMore: Bool?
}

// MARK: - Settlement API Service Implementation

final class SettlementAPIService: SettlementAPIServiceProtocol {

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
        try await apiClient.callFunction(
            "getTradeSettlement",
            parameters: ["tradeId": tradeId]
        )
    }

    func fetchAccountStatement(limit: Int = 50, skip: Int = 0, entryType: String? = nil) async throws -> BackendAccountStatementResponse {
        var params: [String: Any] = ["limit": limit, "skip": skip]
        if let entryType = entryType {
            params["entryType"] = entryType
        }
        return try await apiClient.callFunction(
            "getAccountStatement",
            parameters: params
        )
    }

    func fetchTradeInvoices(tradeId: String) async throws -> BackendInvoiceListResponse {
        try await apiClient.callFunction(
            "getTradeInvoices",
            parameters: ["tradeId": tradeId]
        )
    }

    func fetchUserInvoices(limit: Int = 50, skip: Int = 0, invoiceType: String? = nil) async throws -> BackendInvoiceListResponse {
        var params: [String: Any] = ["limit": limit, "skip": skip]
        if let invoiceType = invoiceType {
            params["invoiceType"] = invoiceType
        }
        return try await apiClient.callFunction(
            "getUserInvoices",
            parameters: params
        )
    }

    func fetchInvestorCollectionBills(limit: Int = 50, skip: Int = 0, investmentId: String? = nil, tradeId: String? = nil) async throws -> BackendCollectionBillResponse {
        var params: [String: Any] = ["limit": limit, "skip": skip]
        if let investmentId = investmentId { params["investmentId"] = investmentId }
        if let tradeId = tradeId { params["tradeId"] = tradeId }
        return try await apiClient.callFunction(
            "getInvestorCollectionBills",
            parameters: params
        )
    }
}
