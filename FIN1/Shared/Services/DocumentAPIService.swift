import Foundation

// MARK: - Document API Service Protocol

/// Protocol for syncing documents to Parse Server backend
protocol DocumentAPIServiceProtocol {
    /// Saves a document to the Parse Server
    func saveDocument(_ document: Document) async throws -> Document

    /// Updates an existing document on the Parse Server
    func updateDocument(_ document: Document) async throws -> Document

    /// Fetches all documents for a user
    func fetchDocuments(for userId: String) async throws -> [Document]

    /// Fetches a single Document row by Parse `objectId` (notification deep-links).
    func fetchDocument(by objectId: String) async throws -> Document

    /// Deletes a document from the Parse Server
    func deleteDocument(_ documentId: String) async throws
}

// MARK: - Parse Document Input

/// Input struct for creating/updating documents on Parse Server
private struct ParseDocumentInput: Codable {
    let userId: String
    let name: String
    let type: String
    let status: String
    let fileURL: String
    let size: Int64
    let uploadedAt: String
    let verifiedAt: String?
    let expiresAt: String?
    let readAt: String?
    let downloadedAt: String?
    let tradeId: String?
    let investmentId: String?
    let statementYear: Int?
    let statementMonth: Int?
    let statementRole: String?
    let documentNumber: String?
    let accountingDocumentNumber: String?
    let traderCommissionRateSnapshot: Double?

    static func from(document: Document) -> ParseDocumentInput {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return ParseDocumentInput(
            userId: document.userId,
            name: document.name,
            type: document.type.rawValue,
            status: document.status.rawValue,
            fileURL: document.fileURL,
            size: document.size,
            uploadedAt: dateFormatter.string(from: document.uploadedAt),
            verifiedAt: document.verifiedAt.map { dateFormatter.string(from: $0) },
            expiresAt: document.expiresAt.map { dateFormatter.string(from: $0) },
            readAt: document.readAt.map { dateFormatter.string(from: $0) },
            downloadedAt: document.downloadedAt.map { dateFormatter.string(from: $0) },
            tradeId: document.tradeId,
            investmentId: document.investmentId,
            statementYear: document.statementYear,
            statementMonth: document.statementMonth,
            statementRole: document.statementRole?.rawValue,
            documentNumber: document.documentNumber,
            accountingDocumentNumber: document.accountingDocumentNumber,
            traderCommissionRateSnapshot: document.traderCommissionRateSnapshot
        )
    }
}

// MARK: - Parse Document Response

/// Minimal decode shape for Parse `Pointer` columns (e.g. `tradeId`, `investmentId`).
private struct ParseDocumentPointerBody: Decodable {
    let objectId: String?
}

/// Response struct for Parse Server document operations
private struct ParseDocumentResponse: Decodable {
    let objectId: String
    let userId: String
    let name: String
    let type: String
    let status: String
    let fileURL: String
    let size: Int64
    let uploadedAt: String
    let updatedAt: String
    let verifiedAt: String?
    let expiresAt: String?
    let readAt: String?
    let downloadedAt: String?
    let tradeId: String?
    let investmentId: String?
    let statementYear: Int?
    let statementMonth: Int?
    let statementRole: String?
    let documentNumber: String?
    let accountingDocumentNumber: String?
    let traderCommissionRateSnapshot: Double?
    let accountingSummaryText: String?

    enum CodingKeys: String, CodingKey {
        case objectId
        case userId
        case name
        case type
        case status
        case fileURL
        case size
        case uploadedAt
        case updatedAt
        case verifiedAt
        case expiresAt
        case readAt
        case downloadedAt
        case tradeId
        case investmentId
        case statementYear
        case statementMonth
        case statementRole
        case documentNumber
        case accountingDocumentNumber
        case traderCommissionRateSnapshot
        case accountingSummaryText
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.objectId = try c.decode(String.self, forKey: .objectId)
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Document"
        self.type = try c.decodeIfPresent(String.self, forKey: .type) ?? DocumentType.other.rawValue
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? DocumentStatus.verified.rawValue
        self.fileURL = try c.decodeIfPresent(String.self, forKey: .fileURL) ?? ""
        self.size = c.decodeLossyInt64(forKey: .size) ?? 0
        self.uploadedAt = try c.decodeIfPresent(String.self, forKey: .uploadedAt) ?? Date().ISO8601Format()
        self.updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? self.uploadedAt
        self.verifiedAt = try c.decodeIfPresent(String.self, forKey: .verifiedAt)
        self.expiresAt = try c.decodeIfPresent(String.self, forKey: .expiresAt)
        self.readAt = try c.decodeIfPresent(String.self, forKey: .readAt)
        self.downloadedAt = try c.decodeIfPresent(String.self, forKey: .downloadedAt)
        self.userId = c.decodeParseStringOrPointerObjectId(forKey: .userId) ?? ""
        self.tradeId = c.decodeParseStringOrPointerObjectId(forKey: .tradeId)
        self.investmentId = c.decodeParseStringOrPointerObjectId(forKey: .investmentId)
        self.statementYear = c.decodeLossyInt(forKey: .statementYear)
        self.statementMonth = c.decodeLossyInt(forKey: .statementMonth)
        self.statementRole = try c.decodeIfPresent(String.self, forKey: .statementRole)
        self.documentNumber = try c.decodeIfPresent(String.self, forKey: .documentNumber)
        self.accountingDocumentNumber = try c.decodeIfPresent(String.self, forKey: .accountingDocumentNumber)
        self.traderCommissionRateSnapshot = c.decodeLossyDouble(forKey: .traderCommissionRateSnapshot)
        self.accountingSummaryText = try c.decodeIfPresent(String.self, forKey: .accountingSummaryText)
    }

    func toDocument() -> Document {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let uploadedDate = dateFormatter.date(from: self.uploadedAt) ?? Date()
        let verifiedDate = self.verifiedAt.flatMap { dateFormatter.date(from: $0) }
        let expiresDate = self.expiresAt.flatMap { dateFormatter.date(from: $0) }
        let readDate = self.readAt.flatMap { dateFormatter.date(from: $0) }
        let downloadedDate = self.downloadedAt.flatMap { dateFormatter.date(from: $0) }

        let documentType = DocumentType(rawValue: type) ?? .other
        let documentStatus = DocumentStatus(rawValue: status) ?? .pending
        let role = self.statementRole.flatMap { UserRole(rawValue: $0) }

        var document = Document(
            id: objectId,
            userId: userId,
            name: name,
            type: documentType,
            status: documentStatus,
            fileURL: fileURL,
            size: size,
            uploadedAt: uploadedDate,
            verifiedAt: verifiedDate,
            expiresAt: expiresDate,
            invoiceData: nil, // Invoice data not stored in Parse (stored separately)
            tradeId: tradeId,
            investmentId: investmentId,
            statementYear: statementYear,
            statementMonth: statementMonth,
            statementRole: role,
            documentNumber: documentNumber ?? self.accountingDocumentNumber,
            traderCommissionRateSnapshot: self.traderCommissionRateSnapshot,
            accountingSummaryText: self.accountingSummaryText
        )
        // Set var properties after initialization
        document.readAt = readDate
        document.downloadedAt = downloadedDate
        return document
    }
}

private extension KeyedDecodingContainer where K == ParseDocumentResponse.CodingKeys {
    /// Parse may return a plain string id or a `Pointer` `{ "__type": "Pointer", "objectId": "..." }`.
    func decodeParseStringOrPointerObjectId(forKey key: K) -> String? {
        if let s = try? decodeIfPresent(String.self, forKey: key) {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        if let ptr = try? decodeIfPresent(ParseDocumentPointerBody.self, forKey: key),
           let oid = ptr.objectId?.trimmingCharacters(in: .whitespacesAndNewlines), !oid.isEmpty {
            return oid
        }
        return nil
    }

    func decodeLossyInt(forKey key: K) -> Int? {
        if let v = try? decodeIfPresent(Int.self, forKey: key) {
            return v
        }
        if let s = try? decodeIfPresent(String.self, forKey: key), let v = Int(s) {
            return v
        }
        return nil
    }

    func decodeLossyInt64(forKey key: K) -> Int64? {
        if let v = try? decodeIfPresent(Int64.self, forKey: key) {
            return v
        }
        if let i = try? decodeIfPresent(Int.self, forKey: key) {
            return Int64(i)
        }
        if let s = try? decodeIfPresent(String.self, forKey: key), let v = Int64(s) {
            return v
        }
        return nil
    }

    func decodeLossyDouble(forKey key: K) -> Double? {
        if let v = try? decodeIfPresent(Double.self, forKey: key) {
            return v
        }
        if let s = try? decodeIfPresent(String.self, forKey: key), let v = Double(s) {
            return v
        }
        return nil
    }
}

// MARK: - Document API Service Implementation

/// Service for syncing documents with Parse Server backend
final class DocumentAPIService: DocumentAPIServiceProtocol {
    private let apiClient: ParseAPIClientProtocol
    private let className = "Document"

    init(apiClient: ParseAPIClientProtocol) {
        self.apiClient = apiClient
    }

    // MARK: - Save Document

    func saveDocument(_ document: Document) async throws -> Document {
        print("📡 DocumentAPIService: Saving document to Parse Server")

        let input = ParseDocumentInput.from(document: document)
        let response = try await apiClient.createObject(
            className: self.className,
            object: input
        )

        print("✅ DocumentAPIService: Document saved with objectId: \(response.objectId)")

        // Return document with Parse objectId
        var savedDocument = Document(
            id: response.objectId,
            userId: document.userId,
            name: document.name,
            type: document.type,
            status: document.status,
            fileURL: document.fileURL,
            size: document.size,
            uploadedAt: document.uploadedAt,
            verifiedAt: document.verifiedAt,
            expiresAt: document.expiresAt,
            invoiceData: document.invoiceData,
            tradeId: document.tradeId,
            investmentId: document.investmentId,
            statementYear: document.statementYear,
            statementMonth: document.statementMonth,
            statementRole: document.statementRole,
            documentNumber: document.documentNumber,
            traderCommissionRateSnapshot: document.traderCommissionRateSnapshot
        )
        // Set var properties after initialization
        savedDocument.readAt = document.readAt
        savedDocument.downloadedAt = document.downloadedAt
        return savedDocument
    }

    // MARK: - Update Document

    func updateDocument(_ document: Document) async throws -> Document {
        print("📡 DocumentAPIService: Updating document on Parse Server")

        let input = ParseDocumentInput.from(document: document)
        let response = try await apiClient.updateObject(
            className: self.className,
            objectId: document.id,
            object: input
        )

        print("✅ DocumentAPIService: Document updated: \(response.objectId)")

        // Return updated document
        return document
    }

    // MARK: - Fetch Documents

    func fetchDocuments(for userId: String) async throws -> [Document] {
        print("📡 DocumentAPIService: Fetching documents for user: \(userId)")

        let responses: [ParseDocumentResponse] = try await apiClient.fetchObjects(
            className: self.className,
            query: ["userId": userId],
            include: nil,
            orderBy: "-uploadedAt",
            limit: 100
        )

        print("✅ DocumentAPIService: Fetched \(responses.count) documents")
        return responses.map { $0.toDocument() }
    }

    func fetchDocument(by objectId: String) async throws -> Document {
        print("📡 DocumentAPIService: Fetching single document \(objectId)")
        let response: ParseDocumentResponse = try await apiClient.fetchObject(
            className: self.className,
            objectId: objectId,
            include: nil
        )
        return response.toDocument()
    }

    // MARK: - Delete Document

    func deleteDocument(_ documentId: String) async throws {
        print("📡 DocumentAPIService: Deleting document: \(documentId)")

        try await self.apiClient.deleteObject(
            className: self.className,
            objectId: documentId
        )

        print("✅ DocumentAPIService: Document deleted")
    }
}
