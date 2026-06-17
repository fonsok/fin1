import Foundation

extension TraderAccountStatementBuilder {
    /// Builds a trader account statement snapshot including wallet transactions.
    /// Uses backend `AccountStatement` entries for commission data when available,
    /// falling back to local credit note invoices otherwise.
    static func buildSnapshotWithWallet(
        for user: User?,
        invoiceService: any InvoiceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        paymentService: (any PaymentServiceProtocol)?,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil
    ) async -> TraderAccountStatementSnapshot {
        let baseSnapshot: TraderAccountStatementSnapshot

        if let settlementService = settlementAPIService {
            baseSnapshot = await buildSnapshotWithBackendCommissions(
                for: user,
                invoiceService: invoiceService,
                configurationService: configurationService,
                settlementAPIService: settlementService
            )
        } else if configurationService.traderStatementServerOnly {
            let openingBalance = configurationService.initialAccountBalance
            print("⚠️ TraderAccountStatementBuilder: \(TraderMonetaryMessages.accountStatementUnavailable) (no settlement API)")
            baseSnapshot = self.emptyServerOnlySnapshot(openingBalance: openingBalance)
        } else {
            baseSnapshot = buildSnapshot(
                for: user,
                invoiceService: invoiceService,
                configurationService: configurationService
            )
        }

        let backendCoversWalletMovements = baseSnapshot.entries.contains {
            $0.category == .walletDeposit || $0.category == .walletWithdrawal
        }

        let walletEntries: [AccountStatementEntry]
        let walletDelta: Double
        if backendCoversWalletMovements {
            walletEntries = []
            walletDelta = 0
        } else {
            (walletEntries, walletDelta) = await self.loadWalletEntriesAndDelta(
                for: user,
                paymentService: paymentService
            )
        }

        let allEntries = baseSnapshot.entries + walletEntries
        let recalculatedEntries = self.recalculateBalanceAfter(
            entries: allEntries,
            openingBalance: baseSnapshot.openingBalance
        )
        let combinedClosingBalance: Double
        if let settlementAPIService,
           let serverBalance = await UserCashBalanceResolver.fetchCurrentBalance(
               settlementAPIService: settlementAPIService
           ) {
            combinedClosingBalance = serverBalance
        } else {
            combinedClosingBalance = backendCoversWalletMovements
                ? (recalculatedEntries.last?.balanceAfter ?? baseSnapshot.closingBalance)
                : baseSnapshot.closingBalance + walletDelta
        }

        return TraderAccountStatementSnapshot(
            entries: AccountStatementEntry.sortedForChronologicalDisplay(recalculatedEntries),
            openingBalance: baseSnapshot.openingBalance,
            closingBalance: combinedClosingBalance,
            timelineTruncated: baseSnapshot.timelineTruncated
        )
    }

    /// Loads wallet transactions and calculates delta for the given user.
    static func loadWalletEntriesAndDelta(
        for user: User?,
        paymentService: (any PaymentServiceProtocol)?
    ) async -> ([AccountStatementEntry], Double) {
        guard let paymentService = paymentService,
              let userId = user?.id else {
            return ([], 0.0)
        }

        do {
            let walletTransactions = try await paymentService.getTransactionHistory(limit: 1_000, offset: 0)
            let userWalletTransactions = walletTransactions.filter { $0.userId == userId }

            let accountOnlyTransactions = userWalletTransactions.filter { transaction in
                switch transaction.type {
                case .deposit, .withdrawal:
                    return true
                default:
                    return false
                }
            }

            let walletEntries = accountOnlyTransactions.map { transaction in
                AccountStatementEntry.from(transaction: transaction)
            }

            let walletDelta = accountOnlyTransactions.reduce(0.0) { total, transaction in
                switch transaction.type {
                case .deposit:
                    return total + transaction.amount
                case .withdrawal:
                    return total - transaction.amount
                default:
                    return total
                }
            }

            return (walletEntries, walletDelta)
        } catch {
            print(
                "⚠️ TraderAccountStatementBuilder: Wallet transactions unavailable (\(error.localizedDescription)) — showing invoice-based entries only"
            )
            return ([], 0.0)
        }
    }

    /// Recalculates balanceAfter for all entries in chronological order.
    static func recalculateBalanceAfter(
        entries: [AccountStatementEntry],
        openingBalance: Double
    ) -> [AccountStatementEntry] {
        let sortedEntries = AccountStatementEntry.sortedForChronologicalDisplay(entries)
        var runningBalance = openingBalance
        var recalculatedEntries: [AccountStatementEntry] = []

        for entry in sortedEntries {
            runningBalance += entry.signedAmount
            let recalculatedEntry = AccountStatementEntry(
                id: entry.id,
                title: entry.title,
                subtitle: entry.subtitle,
                occurredAt: entry.occurredAt,
                amount: entry.amount,
                direction: entry.direction,
                category: entry.category,
                reference: entry.reference,
                referenceDocumentId: entry.referenceDocumentId,
                referenceDocumentNumber: entry.referenceDocumentNumber,
                metadata: entry.metadata,
                balanceAfter: runningBalance,
                valueDate: entry.valueDate
            )
            recalculatedEntries.append(recalculatedEntry)
        }

        return recalculatedEntries
    }
}
