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
        } else {
            baseSnapshot = buildSnapshot(
                for: user,
                invoiceService: invoiceService,
                configurationService: configurationService
            )
        }

        let (walletEntries, walletDelta) = await loadWalletEntriesAndDelta(
            for: user,
            paymentService: paymentService
        )

        let allEntries = baseSnapshot.entries + walletEntries
        let recalculatedEntries = self.recalculateBalanceAfter(
            entries: allEntries,
            openingBalance: baseSnapshot.openingBalance
        )
        let combinedClosingBalance = baseSnapshot.closingBalance + walletDelta

        return TraderAccountStatementSnapshot(
            entries: recalculatedEntries.sorted { $0.occurredAt > $1.occurredAt },
            openingBalance: baseSnapshot.openingBalance,
            closingBalance: combinedClosingBalance
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

            let walletEntries = userWalletTransactions.map { transaction in
                AccountStatementEntry.from(transaction: transaction)
            }

            let walletDelta = userWalletTransactions.reduce(0.0) { total, transaction in
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
        let sortedEntries = entries.sorted { $0.occurredAt < $1.occurredAt }
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
