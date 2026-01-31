import Foundation

// MARK: - Transaction ID Service Protocol

/// Protocol for generating unique transaction identifiers following financial sector standards
protocol TransactionIdServiceProtocol: ServiceLifecycle {

    /// Generates a unique order ID in format: <PREFIX>-ORD-YYYYMMDD-HHMMSS-XXXXX
    /// - Returns: Unique order identifier
    func generateOrderId() -> String

    /// Generates a unique trade ID in format: <PREFIX>-TRD-YYYYMMDD-HHMMSS-XXXXX
    /// - Returns: Unique trade identifier
    func generateTradeId() -> String

    /// Generates a unique invoice number in format: <PREFIX>-INV-YYYYMMDD-XXXXX
    /// - Returns: Unique invoice number
    func generateInvoiceNumber() -> String

    /// Generates a unique investor document number in format: <PREFIX>-INVST-YYYYMMDD-XXXXX
    /// - Returns: Unique investor document identifier
    func generateInvestorDocumentNumber() -> String

    /// Generates a unique payment ID in format: <PREFIX>-PAY-YYYYMMDD-HHMMSS-XXXXX
    /// - Returns: Unique payment identifier
    func generatePaymentId() -> String

    /// Generates a unique customer ID in format: <PREFIX>-YYYY-XXXXX
    /// - Returns: Unique customer identifier
    func generateCustomerId() -> String

    /// Validates if an ID follows the expected format
    /// - Parameter id: The ID to validate
    /// - Returns: True if the ID format is valid
    func validateId(_ id: String) -> Bool
}
