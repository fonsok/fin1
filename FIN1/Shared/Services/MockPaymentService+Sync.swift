import Foundation

extension MockPaymentService {
    func loadTransactionsFromParseServer() async {
        guard let parseClient = parseAPIClient,
              let userId = userService.currentUser?.id else {
            return
        }
        do {
            let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
            let parseTransactions: [ParseWalletTransaction] = try await parseClient.fetchObjects(
                className: "WalletTransaction",
                query: [
                    "userId": userId,
                    "timestamp": ["$gte": ["__type": "Date", "iso": ninetyDaysAgo.iso8601String]]
                ],
                include: [],
                orderBy: "-timestamp",
                limit: 100
            )
            transactions = mergeTransactions(primary: transactions, secondary: parseTransactions.map { $0.toTransaction() })
            logger.info("✅ Loaded \(parseTransactions.count) transactions from Parse Server")
        } catch {
            logger.error("⚠️ Failed to load transactions from Parse Server: \(error.localizedDescription)")
        }
    }

    /// Syncs any pending transactions to the backend.
    /// Called automatically when app enters background.
    func syncToBackend() async {
        guard let parseClient = parseAPIClient,
              let userId = userService.currentUser?.id else {
            logger.info("⚠️ MockPaymentService: No API client configured, skipping sync")
            return
        }
        let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        let recentTransactions = transactions.filter { $0.userId == userId && $0.timestamp >= twentyFourHoursAgo }
        guard !recentTransactions.isEmpty else {
            logger.info("📤 MockPaymentService: No recent transactions to sync")
            return
        }
        logger.info("📤 MockPaymentService: Syncing \(recentTransactions.count) recent transactions to backend...")
        var syncedCount = 0
        var failedCount = 0
        for transaction in recentTransactions {
            do {
                _ = try await parseClient.createObject(
                    className: "WalletTransaction",
                    object: ParseWalletTransaction.from(transaction)
                )
                syncedCount += 1
            } catch {
                logger.debug("⚠️ Failed to sync transaction \(transaction.id): \(error.localizedDescription)")
                failedCount += 1
            }
        }
        logger.info("✅ MockPaymentService: Background sync completed - \(syncedCount) synced, \(failedCount) failed/skipped")
    }

    func mergeTransactions(primary: [Transaction], secondary: [Transaction]) -> [Transaction] {
        var merged: [Transaction] = []
        var seenIds = Set<String>()
        for transaction in primary where !seenIds.contains(transaction.id) {
            merged.append(transaction)
            seenIds.insert(transaction.id)
        }
        for transaction in secondary where !seenIds.contains(transaction.id) {
            merged.append(transaction)
            seenIds.insert(transaction.id)
        }
        return merged.sorted { $0.timestamp > $1.timestamp }
    }
}
