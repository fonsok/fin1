import Foundation

struct InvestorAccountStatementSnapshot {
    let entries: [AccountStatementEntry]
    let openingBalance: Double
    let closingBalance: Double
}

enum InvestorAccountStatementBuilder {
    /// Builds an investor account statement snapshot including wallet transactions
    /// This is the single source of truth for investor balance calculation
    /// - Parameters:
    ///   - user: The investor user
    ///   - investorCashBalanceService: Service for investment transactions and balance
    ///   - paymentService: Optional service for wallet transactions
    /// - Returns: Snapshot with investment + wallet transactions and combined balance
    /// - Throws: AppError if wallet transactions cannot be loaded
    static func buildSnapshotWithWallet(
        for user: User?,
        investorCashBalanceService: any InvestorCashBalanceServiceProtocol,
        paymentService: (any PaymentServiceProtocol)?
    ) async throws -> InvestorAccountStatementSnapshot {
        guard let user = user else {
            let initialBalance = CalculationConstants.Account.initialInvestorBalance
            return InvestorAccountStatementSnapshot(
                entries: [],
                openingBalance: initialBalance,
                closingBalance: initialBalance
            )
        }

        // Load investment transactions (from InvestorCashBalanceService Ledger)
        let investmentLedger = investorCashBalanceService.getTransactions(for: user.id)

        // Get base balance from service (this includes wallet transactions that were processed via processDeposit/Withdrawal)
        let serviceBalance = investorCashBalanceService.getBalance(for: user.id)

        // Load wallet transactions (deposits/withdrawals)
        let walletEntries = try await loadWalletEntries(for: user, paymentService: paymentService)

        // Combine investment and wallet entries
        let allEntries = investmentLedger + walletEntries

        // Calculate opening balance from all entries
        let openingBalance = calculateOpeningBalance(serviceBalance: serviceBalance, entries: allEntries)

        // Recalculate balanceAfter for all entries in chronological order
        let recalculatedEntries = recalculateBalanceAfter(entries: allEntries, openingBalance: openingBalance)

        // Return entries sorted by date descending (newest first) for display
        return InvestorAccountStatementSnapshot(
            entries: recalculatedEntries.sorted { $0.occurredAt > $1.occurredAt },
            openingBalance: openingBalance,
            closingBalance: serviceBalance
        )
    }

    // MARK: - Private Helper Methods

    /// Loads wallet transactions for the given user
    /// - Parameters:
    ///   - user: The investor user
    ///   - paymentService: Optional payment service
    /// - Returns: Array of AccountStatementEntry for wallet transactions
    /// - Throws: AppError if loading fails
    private static func loadWalletEntries(
        for user: User,
        paymentService: (any PaymentServiceProtocol)?
    ) async throws -> [AccountStatementEntry] {
        guard let paymentService = paymentService else {
            return []
        }

        do {
            let walletTransactions = try await paymentService.getTransactionHistory(limit: 1000, offset: 0)
            let userWalletTransactions = walletTransactions.filter { $0.userId == user.id }

            return userWalletTransactions.map { transaction in
                AccountStatementEntry.from(transaction: transaction)
            }
        } catch {
            // Map error to AppError and throw
            _ = error.toAppError() // Error mapping for potential future use
            throw AppError.service(.operationFailed)
        }
    }

    /// Calculates the opening balance from service balance and all entries
    /// - Parameters:
    ///   - serviceBalance: Current balance from service
    ///   - entries: All account statement entries
    /// - Returns: Calculated opening balance
    private static func calculateOpeningBalance(
        serviceBalance: Double,
        entries: [AccountStatementEntry]
    ) -> Double {
        let totalDelta = entries.reduce(0.0) { $0 + $1.signedAmount }
        let calculatedOpening = serviceBalance - totalDelta
        return max(0, calculatedOpening)
    }

    /// Recalculates balanceAfter for all entries in chronological order
    /// - Parameters:
    ///   - entries: All account statement entries
    ///   - openingBalance: Opening balance to start from
    /// - Returns: Array of entries with recalculated balanceAfter values
    private static func recalculateBalanceAfter(
        entries: [AccountStatementEntry],
        openingBalance: Double
    ) -> [AccountStatementEntry] {
        let sortedEntries = entries.sorted { $0.occurredAt < $1.occurredAt }
        var runningBalance = openingBalance
        var recalculatedEntries: [AccountStatementEntry] = []

        for entry in sortedEntries {
            // Update running balance
            runningBalance += entry.signedAmount

            // Create new entry with recalculated balanceAfter
            let recalculatedEntry = AccountStatementEntry(
                id: entry.id,
                title: entry.title,
                subtitle: entry.subtitle,
                occurredAt: entry.occurredAt,
                amount: entry.amount,
                direction: entry.direction,
                category: entry.category,
                reference: entry.reference,
                metadata: entry.metadata,
                balanceAfter: runningBalance,
                valueDate: entry.valueDate
            )
            recalculatedEntries.append(recalculatedEntry)
        }

        return recalculatedEntries
    }
}
