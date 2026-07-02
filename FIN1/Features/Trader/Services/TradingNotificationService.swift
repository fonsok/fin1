import Combine
import Foundation

// MARK: - Trading Notification Service Implementation
final class TradingNotificationService: TradingNotificationServiceProtocol, ServiceLifecycle, @unchecked Sendable {

    @Published var isLoading = false
    @Published var errorMessage: String?

    let documentService: any DocumentServiceProtocol
    let invoiceService: any InvoiceServiceProtocol
    let transactionIdService: any TransactionIdServiceProtocol
    let userService: any UserServiceProtocol
    let configurationService: any ConfigurationServiceProtocol

    init(
        documentService: any DocumentServiceProtocol,
        invoiceService: any InvoiceServiceProtocol,
        transactionIdService: any TransactionIdServiceProtocol,
        userService: any UserServiceProtocol,
        configurationService: any ConfigurationServiceProtocol
    ) {
        self.documentService = documentService
        self.invoiceService = invoiceService
        self.transactionIdService = transactionIdService
        self.userService = userService
        self.configurationService = configurationService
    }

    func start() {}
    func stop() {}

    func reset() {
        self.errorMessage = nil
    }
}
