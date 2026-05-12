import Foundation
import Combine

// MARK: - Investor Notification Service Protocol
/// Defines the contract for investor notifications and document generation
protocol InvestorNotificationServiceProtocol: ObservableObject {
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // MARK: - Investment Notifications
    func showInvestmentConfirmation(for investment: Investment) async
    func generateInvestmentDocument(for investment: Investment) async
    func sendInvestmentStatusNotification(investmentId: String, status: String) async
}

// MARK: - Investor Notification Service Implementation
/// Handles investor notifications, confirmations, and document generation
final class InvestorNotificationService: InvestorNotificationServiceProtocol, ServiceLifecycle, @unchecked Sendable {
    static let shared = InvestorNotificationService()

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let documentService: any DocumentServiceProtocol
    private let transactionIdService: any TransactionIdServiceProtocol

    init(documentService: any DocumentServiceProtocol = DocumentService.shared,
         transactionIdService: any TransactionIdServiceProtocol = TransactionIdService()) {
        self.documentService = documentService
        self.transactionIdService = transactionIdService
    }

    // MARK: - ServiceLifecycle
    func start() {
        // Notification service doesn't need to load data on start
    }

    func stop() {
        // Clean up any ongoing operations
    }

    func reset() {
        errorMessage = nil
    }

    // MARK: - Investment Notifications

    func showInvestmentConfirmation(for investment: Investment) async {
        // Post notification for investment confirmation
        await MainActor.run {
            NotificationCenter.default.post(
                name: .investmentCompleted,
                object: investment
            )
        }
        print("✅ Investment Confirmation: \(investment.traderName) - €\(investment.amount) invested")
    }

    func generateInvestmentDocument(for investment: Investment) async {
        // Create Investment document for completed investments
        let documentNumber = transactionIdService.generateInvestorDocumentNumber()
        print("📄 Investment Document Generated: \(documentNumber) for Investment #\(investment.id)")

        // Create document for the Investment with industry-standard naming
        let documentName = DocumentNamingUtility.investorCollectionBillName(for: investment)
        let document = Document(
            userId: investment.investorId,
            name: documentName,
            type: .investorCollectionBill,
            status: .verified,
            fileURL: "investment://\(documentNumber).pdf",
            size: 1024 * 60, // Mock 60KB PDF size
            uploadedAt: Date(),
            investmentId: investment.id,
            documentNumber: documentNumber
        )

        // Add document to document service
        do {
            try await documentService.uploadDocument(document)
            print("📄 Investment document added to notifications")
        } catch {
            print("❌ Failed to add Investment document: \(error)")
        }

        // Send notification
        print("🔔 Notification: Investment Document \(documentNumber) is ready for download")
    }

    func sendInvestmentStatusNotification(investmentId: String, status: String) async {
        // Send investment status update notification
        await MainActor.run {
            NotificationCenter.default.post(
                name: .investmentStatusUpdated,
                object: ["investmentId": investmentId, "status": status]
            )
        }
        print("🔔 Investment Status Notification: Investment \(investmentId) status updated to \(status)")
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let investmentCompleted = Notification.Name("investmentCompleted")
    static let investmentStatusUpdated = Notification.Name("investmentStatusUpdated")
    static let investorBalanceDidChange = Notification.Name("investorBalanceDidChange")
    /// Posted from Live Query `onUpdate` (any thread); `InvestorCashBalanceService` applies on the main queue.
    static let investorCashBalanceLiveQueryUpdate = Notification.Name("investorCashBalanceLiveQueryUpdate")
    static let walletTransactionCompleted = Notification.Name("walletTransactionCompleted")
}
