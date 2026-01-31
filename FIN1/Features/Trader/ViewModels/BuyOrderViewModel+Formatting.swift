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
}
