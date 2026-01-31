import Foundation

// MARK: - String Investment Extensions

extension String {
    /// Extracts a short identifier from an investment ID
    /// Returns the first 8 characters of the investment ID
    func extractInvestmentNumber() -> String {
        return String(prefix(8))
    }
}
