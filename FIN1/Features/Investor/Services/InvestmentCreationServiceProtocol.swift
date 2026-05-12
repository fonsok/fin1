import Foundation

// MARK: - Investment Creation Service Protocol
/// Defines the contract for investment creation operations
@MainActor
protocol InvestmentCreationServiceProtocol {
    /// - Parameter deferCashDeductions: Wenn `true`, keine lokalen Kontoauszugs-Buchungen bis nach Backend-Sync (Parse objectId).
    /// - Returns: Batch, Investments, IDs der angelegten Investment-Pools (für Rollback bei Sync-Fehler).
    @discardableResult
    func createInvestment(
        investor: User,
        trader: MockTrader,
        amountPerInvestment: Double,
        numberOfInvestments: Int,
        specialization: String,
        potSelection: InvestmentSelectionStrategy,
        repository: any InvestmentRepositoryProtocol,
        deferCashDeductions: Bool
    ) async throws -> (InvestmentBatch, [Investment], [String])

    /// Lokale Wallet-/Kontoauszugs-Buchungen nach erfolgreichem `saveInvestment` (echte Parse-IDs).
    func applyCashDeductionsAfterBackendSync(
        investor: User,
        batch: InvestmentBatch,
        investments: [Investment]
    ) async
}
