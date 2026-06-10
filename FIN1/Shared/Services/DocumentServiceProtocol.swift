import Combine
import Foundation
import SwiftUI

// MARK: - Deep link resolution errors

enum DocumentDeepLinkResolveError: LocalizedError {
    case backendUnavailable

    var errorDescription: String? {
        switch self {
        case .backendUnavailable:
            return "Dokumente können derzeit nicht geladen werden. Bitte später erneut versuchen."
        }
    }
}

// MARK: - Document Service Protocol
/// Defines the contract for document operations and management
protocol DocumentServiceProtocol: ObservableObject, ServiceLifecycle {
    var documents: [Document] { get }
    var documentsPublisher: AnyPublisher<[Document], Never> { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var showError: Bool { get }

    // MARK: - Document Management
    func loadDocuments(for user: User) async

    /// Refreshes the notifications inbox cache (`getUserDocumentInbox` with TTL unless `force`).
    func refreshUserDocumentInbox(for user: User, force: Bool) async

    /// Merges backend settlement / collection-bill rows into the in-memory inbox cache.
    func mergeDocuments(_ documents: [Document])
    func uploadDocument(_ document: Document) async throws
    func deleteDocument(_ document: Document) async throws
    func downloadDocument(_ document: Document) async throws -> Data

    // MARK: - Document Queries
    func getDocuments(for userId: String) -> [Document]
    func getInboxDocuments(for user: User) -> [Document]
    func getDocumentsByType(_ type: DocumentType, for userId: String) -> [Document]
    func getDocument(by id: String) -> Document?

    /// Local cache first, otherwise fetch Parse `Document` by `objectId` and merge into `documents` (notifications deep-link).
    @MainActor
    func resolveDocumentForDeepLink(objectId: String) async throws -> Document

    /// Trader TBC SSOT via `getTraderDocumentBelegDetail` (enrichment for legacy rows).
    @MainActor
    func fetchTraderBelegDetailEnriched(objectId: String) async throws -> Document
    func getDocumentsForTrade(_ tradeId: String) -> [Document]
    func getDocumentsForInvestment(_ investmentId: String) -> [Document]
    func documentExists(for tradeId: String, ofType type: DocumentType) -> Bool
    func documentExists(forInvestmentId investmentId: String, ofType type: DocumentType) -> Bool

    // MARK: - Document Validation
    func validateDocument(_ document: Document) -> Bool
    func getDocumentStatus(for document: Document) -> DocumentStatus

    // MARK: - Document Status Management
    func markAllDocumentsAsRead()
    func markDocumentAsRead(_ document: Document)

    // MARK: - Backend Synchronization
    func syncToBackend() async
}

// MARK: - Document Service Implementation
/// Handles document operations, storage, and management
final class DocumentService: DocumentServiceProtocol, ServiceLifecycle, @unchecked Sendable {
    static let shared = DocumentService()

    @Published var documents: [Document] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    private var cancellables = Set<AnyCancellable>()
    private var documentAPIService: DocumentAPIServiceProtocol?

    /// Parallel `resolveDocumentForDeepLink` calls for the same Parse `objectId` share one
    /// network fetch (in-flight dedupe). Cleared when each task completes or on `reset()`.
    private var deepLinkResolveTasks: [String: Task<Document, Error>] = [:]

    init(documentAPIService: DocumentAPIServiceProtocol? = nil) {
        self.documentAPIService = documentAPIService
        if documentAPIService == nil {
            #if DEBUG
            self.loadMockDocuments()
            #endif
        }
    }

    var documentsPublisher: AnyPublisher<[Document], Never> {
        self.$documents.eraseToAnyPublisher()
    }

    /// Configure the API service for backend synchronization
    func configure(documentAPIService: DocumentAPIServiceProtocol) {
        self.documentAPIService = documentAPIService
    }

    private var lastInboxRefreshAt: Date?
    private var inboxRefreshTask: Task<Void, Never>?
    private static let inboxRefreshMinInterval: TimeInterval = 45
    private static let inboxFetchMaxAttempts = 2

    private static func sanitizeInboxDocuments(_ documents: [Document]) -> [Document] {
        DocumentInboxPolicy.dedupeInboxDocuments(documents)
            .filter { DocumentInboxPolicy.isDisplayableInNotificationsInbox($0) }
    }

    // MARK: - ServiceLifecycle
    func start() { /* preload documents if needed */ }
    func stop() { /* noop */ }
    func reset() {
        self.inboxRefreshTask?.cancel()
        self.inboxRefreshTask = nil
        self.lastInboxRefreshAt = nil
        for (_, task) in self.deepLinkResolveTasks {
            task.cancel()
        }
        self.deepLinkResolveTasks.removeAll()
        self.documents.removeAll()
    }

    // MARK: - Document Management

    func loadDocuments(for user: User) async {
        await self.refreshUserDocumentInbox(for: user, force: true)
    }

    nonisolated func refreshUserDocumentInbox(for user: User, force: Bool) async {
        await self.refreshUserDocumentInboxOnMainActor(for: user, force: force)
    }

    @MainActor
    private func refreshUserDocumentInboxOnMainActor(for user: User, force: Bool) async {
        if !force,
           let last = lastInboxRefreshAt,
           Date().timeIntervalSince(last) < Self.inboxRefreshMinInterval {
            return
        }

        if let task = inboxRefreshTask {
            await task.value
            if !force { return }
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performInboxRefresh(for: user)
        }
        self.inboxRefreshTask = task
        await task.value
        self.inboxRefreshTask = nil
    }

    @MainActor
    private func performInboxRefresh(for user: User) async {
        guard let apiService = documentAPIService else { return }

        self.isLoading = true
        defer { self.isLoading = false }

        if self.documentAPIService != nil {
            self.documents.removeAll { !DocumentInboxPolicy.isParseBackedDocumentId($0.id) }
        }

        let userKeys = DocumentInboxPolicy.documentInboxUserIdKeys(for: user)
        var lastError: Error?

        for attempt in 1 ... Self.inboxFetchMaxAttempts {
            do {
                let serverDocs = try await self.fetchInboxDocuments(apiService: apiService, user: user)
                self.applyInboxSnapshot(serverDocs, userKeys: userKeys)
                self.lastInboxRefreshAt = Date()
                print(
                    "📄 DocumentService: inbox refresh → \(serverDocs.count) server, "
                        + "\(self.documents.count) cached for user \(user.id)"
                )
                return
            } catch {
                lastError = error
                print("⚠️ DocumentService inbox refresh attempt \(attempt) failed: \(error.localizedDescription)")
                if attempt < Self.inboxFetchMaxAttempts {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }
            }
        }

        if let lastError {
            print("⚠️ DocumentService: inbox refresh exhausted retries: \(lastError.localizedDescription)")
        }
    }

    private func fetchInboxDocuments(
        apiService: any DocumentAPIServiceProtocol,
        user: User
    ) async throws -> [Document] {
        var merged = [String: Document]()
        do {
            for doc in try await apiService.fetchAllUserDocumentInbox() {
                merged[doc.id] = doc
            }
        } catch {
            print("⚠️ getUserDocumentInbox unavailable, falling back to legacy fetch: \(error.localizedDescription)")
            for doc in try await self.fetchInboxDocumentsLegacy(apiService: apiService, user: user) {
                merged[doc.id] = doc
            }
        }

        if user.role == .investor {
            if let bills = try? await apiService.fetchInvestorCollectionBillsForInbox(limit: 100) {
                for doc in bills {
                    merged[doc.id] = doc
                }
                print("📄 DocumentService: merged \(bills.count) investor collection bill(s) from getInvestorCollectionBills")
            }
        }

        return Array(merged.values)
    }

    private func fetchInboxDocumentsLegacy(
        apiService: any DocumentAPIServiceProtocol,
        user: User
    ) async throws -> [Document] {
        var merged = [String: Document]()
        for key in DocumentInboxPolicy.documentInboxUserIdKeys(for: user) {
            let fetched = try await apiService.fetchDocuments(for: key)
            for doc in fetched where DocumentInboxPolicy.isDisplayableInNotificationsInbox(doc) {
                merged[doc.id] = doc
            }
        }
        return Array(merged.values)
    }

    /// Server inbox is SSOT for settlement types; preserve deep-linked rows and non-managed uploads.
    @MainActor
    private func applyInboxSnapshot(_ serverDocs: [Document], userKeys: Set<String>) {
        let serverIds = Set(serverDocs.map(\.id))
        var merged = [String: Document]()

        for doc in self.documents {
            if DocumentInboxPolicy.isServerManagedInboxType(doc.type),
               !DocumentInboxPolicy.isLocalPlaceholderDocument(doc),
               DocumentInboxPolicy.isParseBackedDocumentId(doc.id) {
                if serverIds.contains(doc.id) {
                    merged[doc.id] = doc
                } else if DocumentInboxPolicy.belongsToUser(doc, keys: userKeys) {
                    // Kontoauszug deep-link: keep Parse row for this user until inbox returns it.
                    merged[doc.id] = doc
                }
                continue
            }
            guard DocumentInboxPolicy.belongsToUser(doc, keys: userKeys) else { continue }
            merged[doc.id] = doc
        }

        for doc in serverDocs {
            merged[doc.id] = doc
        }

        self.documents = Self.sanitizeInboxDocuments(Array(merged.values))
    }

    func mergeDocuments(_ incoming: [Document]) {
        guard !incoming.isEmpty else { return }
        var merged = Dictionary(uniqueKeysWithValues: self.documents.map { ($0.id, $0) })
        for doc in incoming where DocumentInboxPolicy.isDisplayableInNotificationsInbox(doc) {
            merged[doc.id] = doc
        }
        self.documents = Self.sanitizeInboxDocuments(Array(merged.values))
        self.lastInboxRefreshAt = Date()
    }


    func uploadDocument(_ document: Document) async throws {
        await MainActor.run {
            self.isLoading = true
        }

        // Add to local storage first
        await MainActor.run {
            self.documents.append(document)
        }

        // Sync to backend (write-through pattern) — skip client placeholders for server-managed beleg types.
        if let apiService = documentAPIService {
            if DocumentInboxPolicy.shouldSyncDocumentToParse(document) {
                Task.detached { [apiService, document] in
                    do {
                        let savedDocument = try await apiService.saveDocument(document)
                        print("✅ Document synced to backend: \(savedDocument.id)")
                    } catch {
                        print("⚠️ Failed to sync document to backend: \(error.localizedDescription)")
                    }
                }
            } else {
                print("ℹ️ DocumentService: local placeholder kept on-device only (no Parse sync): \(document.type.rawValue)")
            }
        } else {
            // Simulate API call if no backend available
            try await Task.sleep(nanoseconds: 800_000_000)
        }

        await MainActor.run {
            self.isLoading = false
            print("📄 DocumentService: Document added, total count: \(self.documents.count), document: \(document.name)")
        }
    }

    func deleteDocument(_ document: Document) async throws {
        await MainActor.run {
            self.isLoading = true
        }

        // Remove from local storage first
        await MainActor.run {
            self.documents.removeAll { $0.id == document.id }
        }

        // Sync deletion to backend (write-through pattern)
        if let apiService = documentAPIService {
            Task.detached { [apiService, document] in
                do {
                    try await apiService.deleteDocument(document.id)
                    print("✅ Document deletion synced to backend: \(document.id)")
                } catch {
                    print("⚠️ Failed to sync document deletion to backend: \(error.localizedDescription)")
                }
            }
        } else {
            // Simulate API call if no backend available
            try await Task.sleep(nanoseconds: 400_000_000)
        }

        await MainActor.run {
            self.isLoading = false
        }
    }

    func downloadDocument(_ document: Document) async throws -> Data {
        // Simulate API call with reduced sleep time for better performance
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds (reduced from 1.5)

        // Return mock data
        return Data("Mock document content".utf8)
    }

    // MARK: - Document Queries

    func getDocuments(for userId: String) -> [Document] {
        let keys: Set<String> = [userId]
        return self.documents.filter { DocumentInboxPolicy.belongsToUser($0, keys: keys) }
    }

    func getInboxDocuments(for user: User) -> [Document] {
        DocumentInboxPolicy.inboxDocuments(from: self.documents, for: user)
    }

    func getDocumentsByType(_ type: DocumentType, for userId: String) -> [Document] {
        return self.documents.filter { $0.userId == userId && $0.type == type }
    }

    func getDocument(by id: String) -> Document? {
        return self.documents.first { $0.id == id }
    }

    @MainActor
    func fetchTraderBelegDetailEnriched(objectId: String) async throws -> Document {
        guard let apiService = documentAPIService else {
            throw DocumentDeepLinkResolveError.backendUnavailable
        }
        let detail = try await apiService.fetchTraderBelegDetail(objectId: objectId)
        let document = detail.toDocument()
        if let idx = documents.firstIndex(where: { $0.id == document.id }) {
            self.documents[idx] = document
        } else {
            self.documents.append(document)
        }
        return document
    }

    @MainActor
    func resolveDocumentForDeepLink(objectId: String) async throws -> Document {
        let id = objectId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else {
            throw DocumentDeepLinkResolveError.backendUnavailable
        }

        if let cached = getDocument(by: id) {
            return cached
        }

        if let inFlight = deepLinkResolveTasks[id] {
            return try await inFlight.value
        }

        guard let apiService = documentAPIService else {
            throw DocumentDeepLinkResolveError.backendUnavailable
        }

        let task = Task<Document, Error> { @MainActor [id, apiService] in
            let fetched = try await apiService.fetchDocument(by: id)
            if let idx = self.documents.firstIndex(where: { $0.id == fetched.id }) {
                self.documents[idx] = fetched
            } else {
                self.documents.append(fetched)
            }
            return fetched
        }

        self.deepLinkResolveTasks[id] = task
        defer { deepLinkResolveTasks[id] = nil }

        return try await task.value
    }

    func getDocumentsForTrade(_ tradeId: String) -> [Document] {
        return self.documents.filter { $0.tradeId == tradeId }
    }

    func getDocumentsForInvestment(_ investmentId: String) -> [Document] {
        return self.documents.filter { $0.investmentId == investmentId }
    }

    func documentExists(for tradeId: String, ofType type: DocumentType) -> Bool {
        return self.documents.contains(where: { $0.tradeId == tradeId && $0.type == type })
    }

    func documentExists(forInvestmentId investmentId: String, ofType type: DocumentType) -> Bool {
        return self.documents.contains(where: { $0.investmentId == investmentId && $0.type == type })
    }

    // MARK: - Document Validation

    func validateDocument(_ document: Document) -> Bool {
        // Basic validation
        return !document.name.isEmpty &&
            !document.fileURL.isEmpty &&
            document.size > 0
    }

    func getDocumentStatus(for document: Document) -> DocumentStatus {
        return document.status
    }

    // MARK: - Private Methods

    private func loadMockDocuments() {
        // Mock documents are for testing/development only
        // Mark them as read so they don't affect unread counts
        var mockDocuments = [
            Document(
                id: "document-1",
                userId: "user1",
                name: "ID Verification",
                type: .identification,
                status: .verified,
                fileURL: "documents/id_verification.pdf",
                size: 1_024 * 1_024, // 1MB
                uploadedAt: Date().addingTimeInterval(-86_400 * 7), // 7 days ago
                verifiedAt: Date().addingTimeInterval(-86_400 * 6), // 6 days ago
                expiresAt: Date().addingTimeInterval(86_400 * 365) // 1 year from now
            ),
            Document(
                id: "document-2",
                userId: "user1",
                name: "Proof of Address",
                type: .address,
                status: .pending,
                fileURL: "documents/address_proof.pdf",
                size: 512 * 1_024, // 512KB
                uploadedAt: Date().addingTimeInterval(-86_400 * 2), // 2 days ago
                verifiedAt: nil,
                expiresAt: Date().addingTimeInterval(86_400 * 90) // 90 days from now
            ),
            Document(
                id: "document-3",
                userId: "user1",
                name: "Income Statement",
                type: .financial,
                status: .rejected,
                fileURL: "documents/income_statement.pdf",
                size: 2_048 * 1_024, // 2MB
                uploadedAt: Date().addingTimeInterval(-86_400 * 14), // 14 days ago
                verifiedAt: nil,
                expiresAt: Date().addingTimeInterval(86_400 * 180) // 180 days from now
            )
        ]

        // Mark all mock documents as read so they don't count as unread
        for i in mockDocuments.indices {
            mockDocuments[i].readAt = Date().addingTimeInterval(-86_400) // Read 1 day ago
        }

        self.documents = mockDocuments
    }

    // MARK: - Document Status Management

    func markAllDocumentsAsRead() {
        for index in self.documents.indices {
            self.documents[index].readAt = Date()
        }
    }

    func markDocumentAsRead(_ document: Document) {
        if let idx = documents.firstIndex(where: { $0.id == document.id }) {
            self.documents[idx].readAt = Date()

            // Sync read status to backend
            if let apiService = documentAPIService {
                Task.detached { [apiService, document] in
                    var updatedDocument = document
                    updatedDocument.readAt = Date()
                    do {
                        _ = try await apiService.updateDocument(updatedDocument)
                    } catch {
                        print("⚠️ Failed to sync read status: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - Backend Synchronization

    /// Syncs any pending documents to the backend
    /// Called automatically when app enters background
    func syncToBackend() async {
        guard let apiService = documentAPIService else {
            print("⚠️ DocumentService: No API service configured, skipping sync")
            return
        }

        // Get documents from last 24 hours (most likely to be pending)
        let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        let recentDocuments = self.documents.filter { $0.uploadedAt >= twentyFourHoursAgo }

        guard !recentDocuments.isEmpty else {
            print("📤 DocumentService: No recent documents to sync")
            return
        }

        print("📤 DocumentService: Syncing \(recentDocuments.count) recent documents to backend...")

        var syncedCount = 0
        var failedCount = 0

        for document in recentDocuments {
            guard DocumentInboxPolicy.shouldSyncDocumentToParse(document) else {
                continue
            }
            do {
                _ = try await apiService.saveDocument(document)
                syncedCount += 1
            } catch {
                // Document might already exist in backend (idempotent)
                print("⚠️ Failed to sync document \(document.id): \(error.localizedDescription)")
                failedCount += 1
            }
        }

        print("✅ DocumentService: Background sync completed - \(syncedCount) synced, \(failedCount) failed/skipped")
    }
}
