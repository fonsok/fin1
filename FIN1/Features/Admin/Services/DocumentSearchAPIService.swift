import Foundation

// MARK: - Document Search API (Beleg-Suche, server-driven)
//
// Verwendet Cloud Functions `searchDocuments` und `getDocumentByObjectId`
// (siehe `backend/parse-server/cloud/functions/admin/reports/searchDocuments.js`).
//
// Designentscheidungen:
// - Pagination via `limit`/`skip` + `hasMore` (kein Total-Count im Default-Pfad,
//   spart DB-Last bei großen Datasets).
// - Filter sind whitelisted; freie Suchbegriffe werden serverseitig auf
//   Substring-Match begrenzt und in der Länge limitiert (ReDoS-Schutz).

protocol DocumentSearchAPIServiceProtocol: Sendable {
    func searchDocuments(_ filters: DocumentSearchFilters, page: DocumentSearchPage) async throws -> DocumentSearchPageResult
    func loadFullDocument(objectId: String) async throws -> Document
}

// MARK: - Filters & Page

struct DocumentSearchFilters: Equatable, Sendable {
    var documentNumber: String = ""
    var freeText: String = ""
    var types: [DocumentType] = []
    var userId: String = ""
    var investmentId: String = ""
    var tradeId: String = ""
    var dateFrom: Date?
    var dateTo: Date?

    var isEmpty: Bool {
        documentNumber.trimmingCharacters(in: .whitespaces).isEmpty
            && freeText.trimmingCharacters(in: .whitespaces).isEmpty
            && types.isEmpty
            && userId.trimmingCharacters(in: .whitespaces).isEmpty
            && investmentId.trimmingCharacters(in: .whitespaces).isEmpty
            && tradeId.trimmingCharacters(in: .whitespaces).isEmpty
            && dateFrom == nil
            && dateTo == nil
    }
}

struct DocumentSearchPage: Equatable, Sendable {
    var limit: Int = 25
    var skip: Int = 0
    var sortBy: String = "uploadedAt"
    var sortOrder: String = "desc"
}

struct DocumentSearchPageResult: Sendable {
    let items: [Document]
    let hasMore: Bool
    let total: Int?
    let limit: Int
    let skip: Int
}

// MARK: - Implementation

final class DocumentSearchAPIService: DocumentSearchAPIServiceProtocol, @unchecked Sendable {
    private let parseAPIClient: any ParseAPIClientProtocol
    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    init(parseAPIClient: any ParseAPIClientProtocol) {
        self.parseAPIClient = parseAPIClient
    }

    func searchDocuments(_ filters: DocumentSearchFilters, page: DocumentSearchPage) async throws -> DocumentSearchPageResult {
        var params: [String: Any] = [
            "limit": min(max(page.limit, 1), 100),
            "skip": max(page.skip, 0),
            "sortBy": page.sortBy,
            "sortOrder": page.sortOrder,
        ]

        let docNumber = filters.documentNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if !docNumber.isEmpty { params["documentNumber"] = docNumber }

        let free = filters.freeText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !free.isEmpty { params["search"] = free }

        if !filters.types.isEmpty {
            params["type"] = filters.types.map(\.rawValue)
        }

        let userId = filters.userId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !userId.isEmpty { params["userId"] = userId }

        let investmentId = filters.investmentId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !investmentId.isEmpty { params["investmentId"] = investmentId }

        let tradeId = filters.tradeId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tradeId.isEmpty { params["tradeId"] = tradeId }

        if let dateFrom = filters.dateFrom { params["dateFrom"] = isoFormatter.string(from: dateFrom) }
        if let dateTo = filters.dateTo { params["dateTo"] = isoFormatter.string(from: dateTo) }

        let response: SearchDocumentsResponse = try await parseAPIClient.callFunction(
            "searchDocuments",
            parameters: params
        )

        return DocumentSearchPageResult(
            items: response.items.map { $0.toDocument(isoFormatter: isoFormatter) },
            hasMore: response.hasMore,
            total: response.total,
            limit: response.limit,
            skip: response.skip
        )
    }

    func loadFullDocument(objectId: String) async throws -> Document {
        let response: DocumentSearchRow = try await parseAPIClient.callFunction(
            "getDocumentByObjectId",
            parameters: ["objectId": objectId]
        )
        return response.toDocument(isoFormatter: isoFormatter)
    }
}

// MARK: - Decoded payloads

private struct SearchDocumentsResponse: Decodable {
    let items: [DocumentSearchRow]
    let hasMore: Bool
    let total: Int?
    let limit: Int
    let skip: Int
}

private struct DocumentSearchRow: Decodable {
    let objectId: String
    let userId: String
    let name: String
    let type: String
    let status: String
    let fileURL: String
    let size: Int64
    let uploadedAt: String?
    let verifiedAt: String?
    let documentNumber: String?
    let accountingDocumentNumber: String?
    let tradeId: String?
    let investmentId: String?
    let statementYear: Int?
    let statementMonth: Int?
    let statementRole: String?
    let accountingSummaryText: String?

    func toDocument(isoFormatter: ISO8601DateFormatter) -> Document {
        let uploaded = uploadedAt.flatMap { isoFormatter.date(from: $0) } ?? Date()
        let verified = verifiedAt.flatMap { isoFormatter.date(from: $0) }
        let role = statementRole.flatMap { UserRole(rawValue: $0) }
        let docType = DocumentType(rawValue: type) ?? .other
        let docStatus = DocumentStatus(rawValue: status) ?? .pending

        return Document(
            id: objectId,
            userId: userId,
            name: name,
            type: docType,
            status: docStatus,
            fileURL: fileURL,
            size: size,
            uploadedAt: uploaded,
            verifiedAt: verified,
            expiresAt: nil,
            invoiceData: nil,
            tradeId: tradeId,
            investmentId: investmentId,
            statementYear: statementYear,
            statementMonth: statementMonth,
            statementRole: role,
            documentNumber: documentNumber ?? accountingDocumentNumber,
            traderCommissionRateSnapshot: nil,
            accountingSummaryText: accountingSummaryText
        )
    }
}
