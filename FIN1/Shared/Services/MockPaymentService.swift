import Foundation
import OSLog

// MARK: - Mock Payment Service
/// Mock implementation of PaymentServiceProtocol for development and testing
/// Simulates payment processing without requiring real payment providers
final class MockPaymentService: PaymentServiceProtocol, ObservableObject, @unchecked Sendable {

    // MARK: - Logger

    let logger = Logger(subsystem: "com.fin1.app", category: "MockPaymentService")

    // MARK: - Properties

    let cashBalanceService: any CashBalanceServiceProtocol
    let investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)?
    let userService: any UserServiceProtocol
    let auditLoggingService: (any AuditLoggingServiceProtocol)?
    let parseAPIClient: (any ParseAPIClientProtocol)?
    var transactions: [Transaction] = []
    let simulatedDelay: UInt64 = 1_000_000_000 // 1 second

    var useParseServer: Bool {
        self.parseAPIClient != nil
    }

    // MARK: - Initialization

    init(
        cashBalanceService: any CashBalanceServiceProtocol,
        userService: any UserServiceProtocol,
        investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)? = nil,
        auditLoggingService: (any AuditLoggingServiceProtocol)? = nil,
        parseAPIClient: (any ParseAPIClientProtocol)? = nil
    ) {
        self.cashBalanceService = cashBalanceService
        self.userService = userService
        self.investorCashBalanceService = investorCashBalanceService
        self.auditLoggingService = auditLoggingService
        self.parseAPIClient = parseAPIClient
    }

    // MARK: - ServiceLifecycle

    func start() async {
        self.logger.info("💰 MockPaymentService started")
        // Load existing transactions from Parse Server if available
        if self.useParseServer {
            await loadTransactionsFromParseServer()
        }
    }

    func stop() async {
        self.logger.info("💰 MockPaymentService stopped")
    }

    func reset() async {
        self.transactions.removeAll()
        self.logger.info("💰 MockPaymentService reset - all transactions cleared")
    }
}
