import Foundation

extension MockPaymentService {
    func deposit(amount: Double) async throws -> Transaction {
        guard amount > 0 else { throw PaymentError.invalidAmount }
        logger.info("💰 Processing deposit: \(amount.formatted(.currency(code: "EUR")))")
        try await Task.sleep(nanoseconds: simulatedDelay)
        guard let userId = userService.currentUser?.id else { throw PaymentError.serviceUnavailable }
        let currentBalance = await getUserSpecificBalance(userId: userId)
        let transaction = Transaction(
            userId: userId,
            type: .deposit,
            amount: amount,
            status: .completed,
            timestamp: Date(),
            description: "Einzahlung (Demo-Modus)",
            metadata: ["source": "mock", "demo_mode": "true"],
            balanceAfter: currentBalance + amount
        )
        await cashBalanceService.processGutschrift(amount: amount)
        if let currentUser = userService.currentUser, currentUser.role == .investor, let investorService = investorCashBalanceService {
            await investorService.processDeposit(investorId: userId, amount: amount)
        }
        transactions.insert(transaction, at: 0)
        persistTransactionIfNeeded(transaction)
        NotificationCenter.default.post(name: .walletTransactionCompleted, object: nil, userInfo: ["userId": userId, "transactionType": "deposit", "amount": amount])
        logComplianceTransaction(userId: userId, transaction: transaction, type: .deposit, amount: amount)
        logger.info("✅ Deposit completed: \(transaction.id)")
        return transaction
    }

    func withdraw(amount: Double) async throws -> Transaction {
        guard amount > 0 else { throw PaymentError.invalidAmount }
        logger.info("💰 Processing withdrawal: \(amount.formatted(.currency(code: "EUR")))")
        guard try await canWithdraw(amount: amount) else { throw PaymentError.insufficientFunds }
        try await Task.sleep(nanoseconds: simulatedDelay)
        guard let userId = userService.currentUser?.id else { throw PaymentError.serviceUnavailable }
        let currentBalance = await getUserSpecificBalance(userId: userId)
        let transaction = Transaction(
            userId: userId,
            type: .withdrawal,
            amount: amount,
            status: .completed,
            timestamp: Date(),
            description: "Auszahlung (Demo-Modus)",
            metadata: ["source": "mock", "demo_mode": "true"],
            balanceAfter: currentBalance - amount
        )
        await cashBalanceService.processWithdrawal(amount: amount)
        if let currentUser = userService.currentUser, currentUser.role == .investor, let investorService = investorCashBalanceService {
            await investorService.processWithdrawal(investorId: userId, amount: amount)
        }
        transactions.insert(transaction, at: 0)
        persistTransactionIfNeeded(transaction)
        logComplianceTransaction(userId: userId, transaction: transaction, type: .withdrawal, amount: amount)
        NotificationCenter.default.post(name: .walletTransactionCompleted, object: nil, userInfo: ["userId": userId, "transactionType": "withdrawal", "amount": amount])
        logger.info("✅ Withdrawal completed: \(transaction.id)")
        return transaction
    }

    func canWithdraw(amount: Double) async throws -> Bool {
        guard amount > 0 else { return false }
        guard let userId = userService.currentUser?.id else { return false }
        let currentBalance = await getUserSpecificBalance(userId: userId)
        return (currentBalance - amount) >= 0.0
    }

    func getTransactionHistory(limit: Int = 50, offset: Int = 0) async throws -> [Transaction] {
        guard let userId = userService.currentUser?.id else {
            logger.warning("⚠️ getTransactionHistory: No current user, returning empty array")
            return []
        }
        var userTransactions = transactions.filter { $0.userId == userId }
        if useParseServer, let parseClient = parseAPIClient {
            do {
                let parseTransactions: [ParseWalletTransaction] = try await parseClient.fetchObjects(
                    className: "WalletTransaction",
                    query: ["userId": userId],
                    include: nil,
                    orderBy: "-timestamp",
                    limit: limit + offset
                )
                userTransactions = mergeTransactions(primary: userTransactions, secondary: parseTransactions.map { $0.toTransaction() })
            } catch {
                logger.error("⚠️ Failed to load transactions from Parse Server: \(error.localizedDescription)")
            }
        }
        let endIndex = min(offset + limit, userTransactions.count)
        guard offset < userTransactions.count else { return [] }
        return Array(userTransactions[offset..<endIndex])
    }

    func getTransaction(transactionId: String) async throws -> Transaction? {
        transactions.first { $0.id == transactionId }
    }

    func addTransaction(_ transaction: Transaction) {
        transactions.insert(transaction, at: 0)
    }

    func getAllTransactions() -> [Transaction] {
        transactions
    }

    func getUserSpecificBalance(userId: String) async -> Double {
        await MainActor.run {
            guard let currentUser = userService.currentUser, currentUser.id == userId else {
                return cashBalanceService.currentBalance
            }
            if currentUser.role == .investor, let investorService = investorCashBalanceService {
                return investorService.getBalance(for: userId)
            }
            return cashBalanceService.currentBalance
        }
    }

    private func persistTransactionIfNeeded(_ transaction: Transaction) {
        if useParseServer, let parseClient = parseAPIClient {
            Task {
                do {
                    _ = try await parseClient.createObject(className: "WalletTransaction", object: ParseWalletTransaction.from(transaction))
                } catch {
                    logger.error("⚠️ Failed to save transaction to Parse Server: \(error.localizedDescription)")
                }
            }
        }
    }

    private func logComplianceTransaction(userId: String, transaction: Transaction, type: ComplianceEventType, amount: Double) {
        guard let auditService = auditLoggingService else { return }
        let complianceEvent = ComplianceEvent(
            eventType: type,
            agentId: userId,
            customerId: userId,
            description: "\(type == .deposit ? "Deposit" : "Withdrawal"): €\(amount.formatted(.number.precision(.fractionLength(2))))",
            severity: .medium,
            requiresReview: false,
            notes: "Transaction ID: \(transaction.id), Balance after: €\((transaction.balanceAfter ?? 0).formatted(.number.precision(.fractionLength(2)))))"
        )
        Task { await auditService.logComplianceEvent(complianceEvent) }
    }
}
