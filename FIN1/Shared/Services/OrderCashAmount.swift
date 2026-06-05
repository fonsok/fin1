import Foundation

// MARK: - Order cash amount (SSOT)

/// **Single source of truth** for translating Stück ↔ EUR on buy/sell orders.
///
/// - Order gross cash is always **`Stück × Brief-Kurs`** (`briefPricePerPiece` / `pricePerSecurity`).
/// - `subscriptionRatio` is **not** part of cash math — use it only for share display
///   (`shares(fromPieces:)`) or denomination hints (`CalculationConstants.SecurityDenominations`).
///
/// See `Documentation/ORDER_CASH_AMOUNT_SSOT.md`.
enum OrderCashAmount {
    /// Gross securities value in EUR (before fees).
    static func grossAmount(quantity: Int, briefPricePerPiece: Double) -> Double {
        Double(quantity) * briefPricePerPiece
    }

    /// Gross securities value in EUR (before fees).
    static func grossAmount(quantity: Double, briefPricePerPiece: Double) -> Double {
        quantity * briefPricePerPiece
    }

    /// Shares derived from Stück — **not** used for affordability caps.
    static func shares(fromPieces pieces: Int, subscriptionRatio: Double) -> Int {
        guard subscriptionRatio > 0 else { return 0 }
        return Int(Double(pieces) / subscriptionRatio)
    }
}
