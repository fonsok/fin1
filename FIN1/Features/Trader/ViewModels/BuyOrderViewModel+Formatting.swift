import Foundation

// MARK: - Formatting Extensions
extension BuyOrderViewModel {

    // Formatted ask price for display
    var formattedAskPrice: String {
        let normalizedString = searchResult.askPrice.replacingOccurrences(of: ",", with: ".")
        if let value = Double(normalizedString) {
            return value.formattedAsLocalizedCurrency()
        }
        return "\(searchResult.askPrice) €"
    }

    // Formatted quantity for display
    var formattedQuantity: String {
        Int(quantity).formattedAsLocalizedInteger()
    }

    // Formatted price for display (takes a Double price)
    func formattedPrice(_ price: Double) -> String {
        price.formattedAsLocalizedCurrency()
    }

    // Formatted number for display (takes an Int)
    func formattedNumber(_ number: Int) -> String {
        number.formattedAsLocalizedInteger()
    }

    // Formatted cost for display (takes a Double cost)
    func formattedCost(_ cost: Double) -> String {
        cost.formattedAsLocalizedCurrency()
    }

    /// Applies German grouping after editing (e.g. `1200` → `1.200`) without fighting live keystrokes.
    func normalizeQuantityTextAfterEditing() {
        let parsed = OrderCalculationUtility.parseGermanQuantity(self.quantityText)
        guard parsed > 0 else { return }

        if parsed > 10_000_000 {
            self.showMaxValueWarning = true
            let capped = 10_000_000
            self.quantity = Double(capped)
            self.quantityText = OrderCalculationUtility.formatGermanQuantity(capped)
            return
        }

        self.showMaxValueWarning = false
        self.quantity = Double(parsed)
        let formatted = OrderCalculationUtility.formatGermanQuantity(parsed)
        if self.quantityText != formatted {
            self.quantityText = formatted
        }
    }
}
