import Foundation

// MARK: - Investor Cash Balance Ledger Service

/// Handles ledger operations for InvestorCashBalanceService
/// Separated to reduce main service file size and improve maintainability
final class InvestorCashBalanceLedgerService {
    /// Ledger entries keyed by investorId for statement detail
    private var ledger: [String: [AccountStatementEntry]] = [:]
    private let ledgerLock = NSLock()

    /// Gets ledger entries for a specific investor
    func getLedgerEntries(for investorId: String) -> [AccountStatementEntry] {
        ledgerLock.lock()
        defer { ledgerLock.unlock() }
        return ledger[investorId] ?? []
    }

    /// Records a transaction in the ledger
    func recordTransaction(
        investorId: String,
        title: String,
        subtitle: String? = nil,
        amount: Double,
        direction: AccountStatementEntry.Direction,
        category: AccountStatementEntry.Category,
        reference: String? = nil,
        metadata: [String: String] = [:],
        balanceAfter: Double
    ) {
        let entry = AccountStatementEntry(
            title: title,
            subtitle: subtitle,
            occurredAt: Date(),
            amount: abs(amount),
            direction: direction,
            category: category,
            reference: reference,
            metadata: metadata,
            balanceAfter: balanceAfter
        )

        ledgerLock.lock()
        var entries = ledger[investorId] ?? []
        entries.append(entry)
        entries.sort { $0.occurredAt < $1.occurredAt }
        ledger[investorId] = entries
        ledgerLock.unlock()
    }

    /// Resets the entire ledger
    func resetLedger() {
        ledgerLock.lock()
        ledger.removeAll()
        ledgerLock.unlock()
    }

    /// Clears transactions for a specific investor
    func clearTransactions(for investorId: String) {
        ledgerLock.lock()
        ledger[investorId] = []
        ledgerLock.unlock()
    }
}

