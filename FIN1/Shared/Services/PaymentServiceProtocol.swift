import Foundation

// MARK: - Payment Service Protocol
/// Protocol for handling wallet payments (deposits and withdrawals)
/// Supports both mock and real implementations
protocol PaymentServiceProtocol: ServiceLifecycle {

    /// Initiates a deposit transaction
    /// - Parameter amount: Amount to deposit (must be positive)
    /// - Returns: Created transaction
    /// - Throws: PaymentError if deposit fails
    func deposit(amount: Double) async throws -> Transaction

    /// Initiates a withdrawal transaction
    /// - Parameter amount: Amount to withdraw (must be positive)
    /// - Returns: Created transaction
    /// - Throws: PaymentError if withdrawal fails (e.g., insufficient funds)
    func withdraw(amount: Double) async throws -> Transaction

    /// Validates if a withdrawal is allowed
    /// - Parameter amount: Amount to withdraw
    /// - Returns: True if withdrawal is allowed, false otherwise
    func canWithdraw(amount: Double) async throws -> Bool

    /// Gets transaction history for the current user
    /// - Parameters:
    ///   - limit: Maximum number of transactions to return
    ///   - offset: Offset for pagination
    /// - Returns: Array of transactions, most recent first
    func getTransactionHistory(limit: Int, offset: Int) async throws -> [Transaction]

    /// Gets a specific transaction by ID
    /// - Parameter transactionId: Transaction ID
    /// - Returns: Transaction if found, nil otherwise
    func getTransaction(transactionId: String) async throws -> Transaction?

    /// Syncs any pending transactions to the backend
    /// Called automatically when app enters background
    func syncToBackend() async
}

// MARK: - Payment Errors

enum PaymentError: LocalizedError {
    case invalidAmount
    case insufficientFunds
    case serviceUnavailable
    case transactionFailed(String)
    case invalidTransactionId

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "Ungültiger Betrag. Der Betrag muss größer als 0 sein."
        case .insufficientFunds:
            return "Unzureichendes Guthaben. Bitte überprüfen Sie Ihr Kontoguthaben."
        case .serviceUnavailable:
            return "Zahlungsservice ist derzeit nicht verfügbar. Bitte versuchen Sie es später erneut."
        case .transactionFailed(let reason):
            return "Transaktion fehlgeschlagen: \(reason)"
        case .invalidTransactionId:
            return "Ungültige Transaktions-ID."
        }
    }
}
