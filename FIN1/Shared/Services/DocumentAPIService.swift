import Foundation

// MARK: - Document API Service Protocol

/// Protocol for syncing documents to Parse Server backend
protocol DocumentAPIServiceProtocol: Sendable {
    /// Saves a document to the Parse Server
    func saveDocument(_ document: Document) async throws -> Document

    /// Updates an existing document on the Parse Server
    func updateDocument(_ document: Document) async throws -> Document

    /// Fetches all documents for a user
    func fetchDocuments(for userId: String) async throws -> [Document]

    /// Fetches a single Document row by Parse `objectId` (notification deep-links).
    func fetchDocument(by objectId: String) async throws -> Document

    /// Enriched trader collection bill (SSOT); session-only Cloud Function.
    func fetchTraderBelegDetail(objectId: String) async throws -> TraderDocumentBelegDetail

    /// Session inbox (one Cloud Function); SSOT for Notifications → Documents.
    func fetchUserDocumentInbox(limit: Int, skip: Int) async throws -> UserDocumentInboxPage

    /// Fetches up to `DocumentInboxPolicy.inboxMaxExtraPages` follow-up pages when `hasMore`.
    func fetchAllUserDocumentInbox() async throws -> [Document]

    /// Investor settlement bills (`getInvestorCollectionBills`); supplements inbox when `userId` is legacy.
    func fetchInvestorCollectionBillsForInbox(limit: Int) async throws -> [Document]

    /// Deletes a document from the Parse Server
    func deleteDocument(_ documentId: String) async throws
}

// MARK: - Trader Beleg detail (Cloud Function)

struct TraderDocumentBelegDetail: Decodable, Sendable {
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
    let accountingSummaryText: String?
    let summarySource: String?
    let metadata: TraderCollectionBillBelegMetadata?

    func toDocument() -> Document {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let uploaded = self.uploadedAt.flatMap { formatter.date(from: $0) } ?? Date()
        let verified = self.verifiedAt.flatMap { formatter.date(from: $0) }
        let docType = DocumentType(rawValue: self.type) ?? .other
        let docStatus = DocumentStatus(rawValue: self.status) ?? .pending

        return Document(
            id: self.objectId,
            userId: self.userId,
            name: self.name,
            type: docType,
            status: docStatus,
            fileURL: self.fileURL,
            size: self.size,
            uploadedAt: uploaded,
            verifiedAt: verified,
            tradeId: self.tradeId,
            investmentId: self.investmentId,
            documentNumber: self.documentNumber ?? self.accountingDocumentNumber,
            accountingSummaryText: self.accountingSummaryText,
            traderCollectionBillMetadata: self.metadata
        )
    }
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
    let createdAt: String?
    let updatedAt: String
    let verifiedAt: String?
    let expiresAt: String?
    let readAt: String?
    let downloadedAt: String?
    let tradeId: String?
    let tradeNumber: Int?
    let investmentId: String?
    let statementYear: Int?
    let statementMonth: Int?
    let statementRole: String?
    let documentNumber: String?
    let accountingDocumentNumber: String?
    let traderCommissionRateSnapshot: Double?
    let accountingSummaryText: String?
    let metadata: TraderCollectionBillBelegMetadata?

    enum CodingKeys: String, CodingKey {
        case objectId
        case userId
        case name
        case type
        case status
        case fileURL
        case size
        case uploadedAt
        case createdAt
        case updatedAt
        case verifiedAt
        case expiresAt
        case readAt
        case downloadedAt
        case tradeId
        case tradeNumber
        case investmentId
        case statementYear
        case statementMonth
        case statementRole
        case documentNumber
        case accountingDocumentNumber
        case traderCommissionRateSnapshot
        case accountingSummaryText
        case metadata
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.objectId = try c.decode(String.self, forKey: .objectId)
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Document"
        self.type = try c.decodeIfPresent(String.self, forKey: .type) ?? DocumentType.other.rawValue
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? DocumentStatus.verified.rawValue
        self.fileURL = try c.decodeIfPresent(String.self, forKey: .fileURL) ?? ""
        self.size = c.decodeLossyInt64(forKey: .size) ?? 0
        if let uploaded = try c.decodeIfPresent(String.self, forKey: .uploadedAt) {
            self.uploadedAt = uploaded
        } else if let created = try c.decodeIfPresent(String.self, forKey: .createdAt) {
            self.uploadedAt = created
        } else {
            self.uploadedAt = Date().ISO8601Format()
        }
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        self.updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? self.uploadedAt
        self.verifiedAt = try c.decodeIfPresent(String.self, forKey: .verifiedAt)
        self.expiresAt = try c.decodeIfPresent(String.self, forKey: .expiresAt)
        self.readAt = try c.decodeIfPresent(String.self, forKey: .readAt)
        self.downloadedAt = try c.decodeIfPresent(String.self, forKey: .downloadedAt)
        self.userId = c.decodeParseStringOrPointerObjectId(forKey: .userId) ?? ""
        self.tradeId = c.decodeParseStringOrPointerObjectId(forKey: .tradeId)
        self.tradeNumber = c.decodeLossyInt(forKey: .tradeNumber)
        self.investmentId = c.decodeParseStringOrPointerObjectId(forKey: .investmentId)
        self.statementYear = c.decodeLossyInt(forKey: .statementYear)
        self.statementMonth = c.decodeLossyInt(forKey: .statementMonth)
        self.statementRole = try c.decodeIfPresent(String.self, forKey: .statementRole)
        self.documentNumber = try c.decodeIfPresent(String.self, forKey: .documentNumber)
        self.accountingDocumentNumber = try c.decodeIfPresent(String.self, forKey: .accountingDocumentNumber)
        self.traderCommissionRateSnapshot = c.decodeLossyDouble(forKey: .traderCommissionRateSnapshot)
        self.accountingSummaryText = try c.decodeIfPresent(String.self, forKey: .accountingSummaryText)
        self.metadata = try c.decodeIfPresent(TraderCollectionBillBelegMetadata.self, forKey: .metadata)
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
            tradeNumber: tradeNumber,
            investmentId: investmentId,
            statementYear: statementYear,
            statementMonth: statementMonth,
            statementRole: role,
            documentNumber: documentNumber ?? self.accountingDocumentNumber,
            traderCommissionRateSnapshot: self.traderCommissionRateSnapshot,
            accountingSummaryText: self.accountingSummaryText,
            traderCollectionBillMetadata: self.metadata
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
final class DocumentAPIService: DocumentAPIServiceProtocol, @unchecked Sendable {
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

    // MARK: - User document inbox (Cloud Function)

    func fetchUserDocumentInbox(limit: Int = DocumentInboxPolicy.inboxPageSize, skip: Int = 0) async throws -> UserDocumentInboxPage {
        print("📡 DocumentAPIService: getUserDocumentInbox limit=\(limit) skip=\(skip)")
        let response: DocumentInboxCloudResponse = try await apiClient.callFunction(
            "getUserDocumentInbox",
            parameters: ["limit": limit, "skip": skip]
        )
        let docs = response.documents.map { $0.toDocument() }
            .filter { DocumentInboxPolicy.isDisplayableInNotificationsInbox($0) }
        print("✅ DocumentAPIService: Inbox page skip=\(skip) → \(docs.count) document(s), hasMore=\(response.hasMore ?? false)")
        return UserDocumentInboxPage(documents: docs, hasMore: response.hasMore ?? false)
    }

    func fetchAllUserDocumentInbox() async throws -> [Document] {
        var merged = [String: Document]()
        var skip = 0
        let pageSize = DocumentInboxPolicy.inboxPageSize
        var pageIndex = 0

        while pageIndex <= DocumentInboxPolicy.inboxMaxExtraPages {
            let page = try await self.fetchUserDocumentInbox(limit: pageSize, skip: skip)
            for doc in page.documents {
                merged[doc.id] = doc
            }
            guard page.hasMore, pageIndex < DocumentInboxPolicy.inboxMaxExtraPages else { break }
            skip += pageSize
            pageIndex += 1
        }

        return Array(merged.values)
    }

    func fetchInvestorCollectionBillsForInbox(limit: Int = 100) async throws -> [Document] {
        print("📡 DocumentAPIService: getInvestorCollectionBills limit=\(limit)")
        let response: InvestorCollectionBillsCloudResponse = try await apiClient.callFunction(
            "getInvestorCollectionBills",
            parameters: ["limit": limit, "skip": 0]
        )
        let docs = response.collectionBills.map { $0.toDocument() }
            .filter { DocumentInboxPolicy.isDisplayableInNotificationsInbox($0) }
        print("✅ DocumentAPIService: getInvestorCollectionBills → \(docs.count) bill(s)")
        return docs
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

    func fetchTraderBelegDetail(objectId: String) async throws -> TraderDocumentBelegDetail {
        let id = objectId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else {
            throw DocumentDeepLinkResolveError.backendUnavailable
        }
        print("📡 DocumentAPIService: getTraderDocumentBelegDetail \(id)")
        return try await self.apiClient.callFunction(
            "getTraderDocumentBelegDetail",
            parameters: ["objectId": id]
        )
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

// MARK: - Inbox Cloud Function response

struct UserDocumentInboxPage: Sendable {
    let documents: [Document]
    let hasMore: Bool
}

private struct InvestorCollectionBillsCloudResponse: Decodable {
    let collectionBills: [ParseDocumentResponse]

    enum CodingKeys: String, CodingKey {
        case collectionBills
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.collectionBills = try c.decodeIfPresent([ParseDocumentResponse].self, forKey: .collectionBills) ?? []
    }
}

private struct DocumentInboxCloudResponse: Decodable {
    let documents: [ParseDocumentResponse]
    let hasMore: Bool?

    enum CodingKeys: String, CodingKey {
        case documents
        case hasMore
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.documents = try c.decodeIfPresent([ParseDocumentResponse].self, forKey: .documents) ?? []
        self.hasMore = try c.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
    }
}
