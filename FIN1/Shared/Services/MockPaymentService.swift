import Foundation
import OSLog

// MARK: - Mock Payment Service
/// Mock implementation of PaymentServiceProtocol for development and testing
/// Simulates payment processing without requiring real payment providers
final class MockPaymentService: PaymentServiceProtocol, ObservableObject {

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.fin1.app", category: "MockPaymentService")

    // MARK: - Properties

    private let cashBalanceService: any CashBalanceServiceProtocol
    private let investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)?
    private let userService: any UserServiceProtocol
    private let auditLoggingService: (any AuditLoggingServiceProtocol)?
    private let parseAPIClient: (any ParseAPIClientProtocol)?
    private var transactions: [Transaction] = []
    private let simulatedDelay: UInt64 = 1_000_000_000 // 1 second

    private var useParseServer: Bool {
        parseAPIClient != nil
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
        logger.info("💰 MockPaymentService started")
        // Load existing transactions from Parse Server if available
        if useParseServer {
            await loadTransactionsFromParseServer()
        }
    }

    func stop() async {
        logger.info("💰 MockPaymentService stopped")
    }

    func reset() async {
        transactions.removeAll()
        logger.info("💰 MockPaymentService reset - all transactions cleared")
    }

    // MARK: - PaymentServiceProtocol

    func deposit(amount: Double) async throws -> Transaction {
        // Validate amount
        guard amount > 0 else {
            throw PaymentError.invalidAmount
        }

        logger.info("💰 Processing deposit: \(amount.formatted(.currency(code: "EUR")))")

        // Simulate network delay
        try await Task.sleep(nanoseconds: simulatedDelay)

        // Get current user
        guard let userId = userService.currentUser?.id else {
            throw PaymentError.serviceUnavailable
        }

        // Get current balance (user-specific if investor)
        let currentBalance = await getUserSpecificBalance(userId: userId)

        // Create transaction
        let transaction = Transaction(
            userId: userId,
            type: .deposit,
            amount: amount,
            status: .completed,
            timestamp: Date(),
            description: "Einzahlung (Demo-Modus)",
            metadata: [
                "source": "mock",
                "demo_mode": "true"
            ],
            balanceAfter: currentBalance + amount
        )

        // Update cash balance (global)
        await cashBalanceService.processGutschrift(amount: amount)

        // Update user-specific balance if investor
        if let currentUser = userService.currentUser,
           currentUser.role == .investor,
           let investorService = investorCashBalanceService {
            await investorService.processDeposit(investorId: userId, amount: amount)
        }

        // Store transaction
        transactions.insert(transaction, at: 0) // Most recent first

        // Save to Parse Server if available (async, don't wait)
        if useParseServer, let parseClient = parseAPIClient {
            Task {
                do {
                    let parseTransaction = ParseWalletTransaction.from(transaction)
                    _ = try await parseClient.createObject(
                        className: "WalletTransaction",
                        object: parseTransaction
                    )
                } catch {
                    logger.error("⚠️ Failed to save transaction to Parse Server: \(error.localizedDescription)")
                }
            }
        }

        // Post notification to update Dashboard
        NotificationCenter.default.post(
            name: .walletTransactionCompleted,
            object: nil,
            userInfo: [
                "userId": userId,
                "transactionType": "deposit",
                "amount": amount
            ]
        )

        // ✅ MiFID II Compliance: Log deposit transaction
        if let auditService = auditLoggingService {
            let complianceEvent = ComplianceEvent(
                eventType: .deposit,
                agentId: userId,
                customerId: userId,
                description: "Deposit: €\(amount.formatted(.number.precision(.fractionLength(2))))",
                severity: .medium,
                requiresReview: false,
                notes: "Transaction ID: \(transaction.id), Balance after: €\((transaction.balanceAfter ?? 0).formatted(.number.precision(.fractionLength(2)))))"
            )
            Task {
                await auditService.logComplianceEvent(complianceEvent)
            }
        }

        logger.info("✅ Deposit completed: \(transaction.id)")

        return transaction
    }

    func withdraw(amount: Double) async throws -> Transaction {
        // Validate amount
        guard amount > 0 else {
            throw PaymentError.invalidAmount
        }

        logger.info("💰 Processing withdrawal: \(amount.formatted(.currency(code: "EUR")))")

        // Check if withdrawal is allowed
        guard try await canWithdraw(amount: amount) else {
            throw PaymentError.insufficientFunds
        }

        // Simulate network delay
        try await Task.sleep(nanoseconds: simulatedDelay)

        // Get current user
        guard let userId = userService.currentUser?.id else {
            throw PaymentError.serviceUnavailable
        }

        // Get current balance (user-specific if investor)
        let currentBalance = await getUserSpecificBalance(userId: userId)

        // Create transaction
        let transaction = Transaction(
            userId: userId,
            type: .withdrawal,
            amount: amount,
            status: .completed,
            timestamp: Date(),
            description: "Auszahlung (Demo-Modus)",
            metadata: [
                "source": "mock",
                "demo_mode": "true"
            ],
            balanceAfter: currentBalance - amount
        )

        // Update cash balance (global)
        await cashBalanceService.processWithdrawal(amount: amount)

        // Update user-specific balance if investor
        if let currentUser = userService.currentUser,
           currentUser.role == .investor,
           let investorService = investorCashBalanceService {
            await investorService.processWithdrawal(investorId: userId, amount: amount)
        }

        // Store transaction
        transactions.insert(transaction, at: 0) // Most recent first

        // Save to Parse Server if available (async, don't wait)
        if useParseServer, let parseClient = parseAPIClient {
            Task {
                do {
                    let parseTransaction = ParseWalletTransaction.from(transaction)
                    _ = try await parseClient.createObject(
                        className: "WalletTransaction",
                        object: parseTransaction
                    )
                } catch {
                    logger.error("⚠️ Failed to save transaction to Parse Server: \(error.localizedDescription)")
                }
            }
        }

        // ✅ MiFID II Compliance: Log withdrawal transaction
        if let auditService = auditLoggingService {
            let complianceEvent = ComplianceEvent(
                eventType: .withdrawal,
                agentId: userId,
                customerId: userId,
                description: "Withdrawal: €\(amount.formatted(.number.precision(.fractionLength(2)))))",
                severity: .medium,
                requiresReview: false,
                notes: "Transaction ID: \(transaction.id), Balance after: €\((transaction.balanceAfter ?? 0).formatted(.number.precision(.fractionLength(2)))))"
            )
            Task {
                await auditService.logComplianceEvent(complianceEvent)
            }
        }

        // Post notification to update Dashboard
        NotificationCenter.default.post(
            name: .walletTransactionCompleted,
            object: nil,
            userInfo: [
                "userId": userId,
                "transactionType": "withdrawal",
                "amount": amount
            ]
        )

        logger.info("✅ Withdrawal completed: \(transaction.id)")

        return transaction
    }

    func canWithdraw(amount: Double) async throws -> Bool {
        guard amount > 0 else {
            return false
        }

        guard let userId = userService.currentUser?.id else {
            return false
        }

        let currentBalance = await getUserSpecificBalance(userId: userId)
        let minimumReserve = 0.0 // Could be configurable

        return (currentBalance - amount) >= minimumReserve
    }

    // MARK: - Helper Methods

    private func getUserSpecificBalance(userId: String) async -> Double {
        guard let currentUser = userService.currentUser,
              currentUser.id == userId else {
            return cashBalanceService.currentBalance
        }

        switch currentUser.role {
        case .investor:
            if let investorService = investorCashBalanceService {
                return investorService.getBalance(for: userId)
            }
            return cashBalanceService.currentBalance
        default:
            return cashBalanceService.currentBalance
        }
    }

    func getTransactionHistory(limit: Int = 50, offset: Int = 0) async throws -> [Transaction] {
        // Get current user
        guard let userId = userService.currentUser?.id else {
            logger.warning("⚠️ getTransactionHistory: No current user, returning empty array")
            return []
        }

        var userTransactions = transactions.filter { $0.userId == userId }

        // Load from Parse Server if available
        if useParseServer, let parseClient = parseAPIClient {
            do {
                let parseTransactions: [ParseWalletTransaction] = try await parseClient.fetchObjects(
                    className: "WalletTransaction",
                    query: ["userId": userId],
                    include: nil,
                    orderBy: "-timestamp",
                    limit: limit + offset
                )

                // Convert to Transaction and merge with in-memory transactions
                let parseConverted = parseTransactions.map { $0.toTransaction() }

                // Merge and deduplicate (prefer in-memory if same ID)
                var merged: [Transaction] = []
                var seenIds = Set<String>()

                // Add in-memory transactions first (they're more recent)
                for transaction in userTransactions {
                    if !seenIds.contains(transaction.id) {
                        merged.append(transaction)
                        seenIds.insert(transaction.id)
                    }
                }

                // Add Parse Server transactions that aren't already in memory
                for transaction in parseConverted {
                    if !seenIds.contains(transaction.id) {
                        merged.append(transaction)
                        seenIds.insert(transaction.id)
                    }
                }

                userTransactions = merged.sorted { $0.timestamp > $1.timestamp }
            } catch {
                logger.error("⚠️ Failed to load transactions from Parse Server: \(error.localizedDescription)")
                // Continue with in-memory transactions only
            }
        }

        // Return transactions, most recent first
        let endIndex = min(offset + limit, userTransactions.count)
        guard offset < userTransactions.count else {
            return []
        }

        return Array(userTransactions[offset..<endIndex])
    }

    func getTransaction(transactionId: String) async throws -> Transaction? {
        return transactions.first { $0.id == transactionId }
    }

    // MARK: - Helper Methods

    /// Adds a transaction to the history (for testing or external sources)
    func addTransaction(_ transaction: Transaction) {
        transactions.insert(transaction, at: 0)
    }

    /// Gets all transactions (for testing)
    func getAllTransactions() -> [Transaction] {
        return transactions
    }

    // MARK: - Parse Server Integration

    private func loadTransactionsFromParseServer() async {
        guard let parseClient = parseAPIClient,
              let userId = userService.currentUser?.id else {
            return
        }

        do {
            // Load last 100 transactions from last 90 days
            let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
            let parseTransactions: [ParseWalletTransaction] = try await parseClient.fetchObjects(
                className: "WalletTransaction",
                query: [
                    "userId": userId,
                    "timestamp": ["$gte": ["__type": "Date", "iso": ninetyDaysAgo.iso8601String]]
                ],
                include: nil,
                orderBy: "-timestamp",
                limit: 100
            )

            // Convert to Transaction and add to in-memory cache
            let converted = parseTransactions.map { $0.toTransaction() }

            // Merge with existing transactions (deduplicate by ID)
            var merged: [Transaction] = []
            var seenIds = Set<String>()

            // Add existing in-memory transactions first
            for transaction in transactions {
                merged.append(transaction)
                seenIds.insert(transaction.id)
            }

            // Add Parse Server transactions that aren't already in memory
            for transaction in converted {
                if !seenIds.contains(transaction.id) {
                    merged.append(transaction)
                    seenIds.insert(transaction.id)
                }
            }

            transactions = merged.sorted { $0.timestamp > $1.timestamp }

            logger.info("✅ Loaded \(converted.count) transactions from Parse Server")
        } catch {
            logger.error("⚠️ Failed to load transactions from Parse Server: \(error.localizedDescription)")
        }
    }

    // MARK: - Backend Synchronization

    /// Syncs any pending transactions to the backend
    /// Called automatically when app enters background
    func syncToBackend() async {
        guard let parseClient = parseAPIClient,
              let userId = userService.currentUser?.id else {
            logger.info("⚠️ MockPaymentService: No API client configured, skipping sync")
            return
        }

        // Get user's transactions from last 24 hours (most likely to be pending)
        let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        let recentTransactions = transactions.filter { transaction in
            transaction.userId == userId && transaction.timestamp >= twentyFourHoursAgo
        }

        guard !recentTransactions.isEmpty else {
            logger.info("📤 MockPaymentService: No recent transactions to sync")
            return
        }

        logger.info("📤 MockPaymentService: Syncing \(recentTransactions.count) recent transactions to backend...")

        var syncedCount = 0
        var failedCount = 0

        for transaction in recentTransactions {
            do {
                let parseTransaction = ParseWalletTransaction.from(transaction)
                _ = try await parseClient.createObject(
                    className: "WalletTransaction",
                    object: parseTransaction
                )
                syncedCount += 1
            } catch {
                // Transaction might already exist in backend (idempotent)
                // Or network error - log but continue
                logger.debug("⚠️ Failed to sync transaction \(transaction.id): \(error.localizedDescription)")
                failedCount += 1
            }
        }

        logger.info("✅ MockPaymentService: Background sync completed - \(syncedCount) synced, \(failedCount) failed/skipped")
    }
}
