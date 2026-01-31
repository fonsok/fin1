import Foundation

// MARK: - Service Protocols (host-implemented)

public protocol CKInvoiceService {
    func getInvoices(for customerId: String) -> [CKInvoice]
    func getInvoicesForTrade(_ tradeId: String) -> [CKInvoice]
}

public protocol CKTradeLifecycleService {
    var completedTrades: [CKTrade] { get }
}

public protocol CKParticipationService {
    func getParticipations(forInvestmentId investmentId: String) -> [CKParticipation]
    func getParticipations(forTradeId tradeId: String) -> [CKParticipation]
}

public protocol CKInvestmentService {
    var investments: [CKInvestment] { get }
}

public protocol CKInvestorCashLedgerService {
    func getTransactions(for userId: String) -> [CKAccountStatementEntry]
    func getBalance(for userId: String) -> Double
}

public protocol CKDocumentService {
    func validate(document: CKDocument) -> Bool
    func upload(document: CKDocument) async throws
    func getDocuments(for userId: String) -> [CKDocument]
}

public protocol CKNotificationService {
    func createNotification(title: String, message: String, type: String, priority: String, for userId: String)
}

public protocol CKUserService {
    var currentUser: CKUser? { get }
}

public protocol CKConfigurationService {
    var initialAccountBalance: Double { get }
}

// MARK: - Service Provider Container

public struct CKServiceProvider {
    public let invoiceService: CKInvoiceService
    public let tradeLifecycleService: CKTradeLifecycleService
    public let participationService: CKParticipationService
    public let investmentService: CKInvestmentService
    public let investorCashLedgerService: CKInvestorCashLedgerService
    public let documentService: CKDocumentService
    public let notificationService: CKNotificationService
    public let userService: CKUserService
    public let configurationService: CKConfigurationService
}














