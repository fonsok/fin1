import Foundation
import SwiftUI
import Combine

// MARK: - Document Service Protocol
/// Defines the contract for document operations and management
protocol DocumentServiceProtocol: ObservableObject, ServiceLifecycle {
    var documents: [Document] { get }
    var documentsPublisher: AnyPublisher<[Document], Never> { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var showError: Bool { get }

    // MARK: - Document Management
    func loadDocuments(for user: User)
    func uploadDocument(_ document: Document) async throws
    func deleteDocument(_ document: Document) async throws
    func downloadDocument(_ document: Document) async throws -> Data

    // MARK: - Document Queries
    func getDocuments(for userId: String) -> [Document]
    func getDocumentsByType(_ type: DocumentType, for userId: String) -> [Document]
    func getDocument(by id: String) -> Document?
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
final class DocumentService: DocumentServiceProtocol, ServiceLifecycle {
    static let shared = DocumentService()

    @Published var documents: [Document] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    private var cancellables = Set<AnyCancellable>()
    private var documentAPIService: DocumentAPIServiceProtocol?

    init(documentAPIService: DocumentAPIServiceProtocol? = nil) {
        self.documentAPIService = documentAPIService
        loadMockDocuments()
    }

    var documentsPublisher: AnyPublisher<[Document], Never> {
        $documents.eraseToAnyPublisher()
    }

    /// Configure the API service for backend synchronization
    func configure(documentAPIService: DocumentAPIServiceProtocol) {
        self.documentAPIService = documentAPIService
    }

    // MARK: - ServiceLifecycle
    func start() { /* preload documents if needed */ }
    func stop() { /* noop */ }
    func reset() { documents.removeAll() }

    // MARK: - Document Management

    func loadDocuments(for user: User) {
        isLoading = true

        // Try to fetch from backend first
        if let apiService = documentAPIService {
            Task {
                do {
                    let fetchedDocuments = try await apiService.fetchDocuments(for: user.id)
                    await MainActor.run {
                        self.documents = fetchedDocuments
                        self.isLoading = false
                    }
                    return
                } catch {
                    print("⚠️ Failed to fetch documents from backend, using local: \(error.localizedDescription)")
                }
            }
        }

        // Fallback to mock data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isLoading = false
        }
    }

    func uploadDocument(_ document: Document) async throws {
        await MainActor.run {
            isLoading = true
        }

        // Add to local storage first
        await MainActor.run {
            self.documents.append(document)
        }

        // Sync to backend (write-through pattern)
        if let apiService = documentAPIService {
            Task.detached { [apiService, document] in
                do {
                    let savedDocument = try await apiService.saveDocument(document)
                    print("✅ Document synced to backend: \(savedDocument.id)")
                } catch {
                    print("⚠️ Failed to sync document to backend: \(error.localizedDescription)")
                }
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
            isLoading = true
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
        return documents.filter { $0.userId == userId }
    }

    func getDocumentsByType(_ type: DocumentType, for userId: String) -> [Document] {
        return documents.filter { $0.userId == userId && $0.type == type }
    }

    func getDocument(by id: String) -> Document? {
        return documents.first { $0.id == id }
    }

    func getDocumentsForTrade(_ tradeId: String) -> [Document] {
        return documents.filter { $0.tradeId == tradeId }
    }

    func getDocumentsForInvestment(_ investmentId: String) -> [Document] {
        return documents.filter { $0.investmentId == investmentId }
    }

    func documentExists(for tradeId: String, ofType type: DocumentType) -> Bool {
        return documents.contains(where: { $0.tradeId == tradeId && $0.type == type })
    }

    func documentExists(forInvestmentId investmentId: String, ofType type: DocumentType) -> Bool {
        return documents.contains(where: { $0.investmentId == investmentId && $0.type == type })
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
                size: 1024 * 1024, // 1MB
                uploadedAt: Date().addingTimeInterval(-86400 * 7), // 7 days ago
                verifiedAt: Date().addingTimeInterval(-86400 * 6), // 6 days ago
                expiresAt: Date().addingTimeInterval(86400 * 365) // 1 year from now
            ),
            Document(
                id: "document-2",
                userId: "user1",
                name: "Proof of Address",
                type: .address,
                status: .pending,
                fileURL: "documents/address_proof.pdf",
                size: 512 * 1024, // 512KB
                uploadedAt: Date().addingTimeInterval(-86400 * 2), // 2 days ago
                verifiedAt: nil,
                expiresAt: Date().addingTimeInterval(86400 * 90) // 90 days from now
            ),
            Document(
                id: "document-3",
                userId: "user1",
                name: "Income Statement",
                type: .financial,
                status: .rejected,
                fileURL: "documents/income_statement.pdf",
                size: 2048 * 1024, // 2MB
                uploadedAt: Date().addingTimeInterval(-86400 * 14), // 14 days ago
                verifiedAt: nil,
                expiresAt: Date().addingTimeInterval(86400 * 180) // 180 days from now
            )
        ]

        // Mark all mock documents as read so they don't count as unread
        for i in mockDocuments.indices {
            mockDocuments[i].readAt = Date().addingTimeInterval(-86400) // Read 1 day ago
        }

        documents = mockDocuments
    }

    // MARK: - Document Status Management

    func markAllDocumentsAsRead() {
        for index in documents.indices {
            documents[index].readAt = Date()
        }
    }

    func markDocumentAsRead(_ document: Document) {
        if let idx = documents.firstIndex(where: { $0.id == document.id }) {
            documents[idx].readAt = Date()

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
        let recentDocuments = documents.filter { $0.uploadedAt >= twentyFourHoursAgo }

        guard !recentDocuments.isEmpty else {
            print("📤 DocumentService: No recent documents to sync")
            return
        }

        print("📤 DocumentService: Syncing \(recentDocuments.count) recent documents to backend...")

        var syncedCount = 0
        var failedCount = 0

        for document in recentDocuments {
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
