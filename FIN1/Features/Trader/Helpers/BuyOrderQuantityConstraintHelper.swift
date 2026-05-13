import Foundation

// MARK: - Buy Order Quantity Constraint Helper

/// Handles quantity constraint validation for buy orders
/// Extracted from BuyOrderViewModel to reduce file size
struct BuyOrderQuantityConstraintHelper {

    let searchResult: SearchResult

    // MARK: - Constraint Evaluation

    /// Evaluates quantity constraints based on denomination rules
    /// - Parameter rawValue: The raw quantity value to evaluate
    /// - Returns: Tuple with valid value (if constraints met) and optional error message
    func evaluateQuantityConstraints(for rawValue: Double) -> (value: Double?, message: String?) {
        guard let denomination = enforcedQuantityDenomination else {
            return (rawValue, nil)
        }

        let integerValue = Int(rawValue)

        guard integerValue > 0 else {
            return (rawValue, nil)
        }

        let remainder = integerValue % denomination
        if remainder == 0 {
            return (rawValue, nil)
        }

        return (nil, self.constraintMessage(for: denomination))
    }

    // MARK: - Constraint Messages

    private func constraintMessage(for denomination: Int) -> String {
        let ratio = self.formattedSubscriptionRatio
        return "Zeichnungsverhältnis \(ratio) → Eingaben nur in \(denomination)-Schritten."
    }

    private var formattedSubscriptionRatio: String {
        let formatter = NumberFormatter.localizedDecimalFormatter
        return formatter.string(from: NSNumber(value: self.searchResult.subscriptionRatio)) ?? "0"
    }

    // MARK: - Denomination Helpers

    private var enforcedQuantityDenomination: Int? {
        if let explicitDenomination = searchResult.denomination, explicitDenomination > 1 {
            return explicitDenomination
        }
        return self.subscriptionRatioDenomination
    }

    private var subscriptionRatioDenomination: Int? {
        guard self.searchResult.subscriptionRatio > 0 else {
            return nil
        }

        guard let defaultDenomination = CalculationConstants.SecurityDenominations
            .defaultDenomination(forSubscriptionRatio: searchResult.subscriptionRatio) else {
            return nil
        }

        if defaultDenomination == 10 || defaultDenomination == 100 {
            return defaultDenomination
        }

        return nil
    }
}

// MARK: - Total Investment Quantity Calculator

/// Calculates total investment quantity based on investments and price
/// Extracted from BuyOrderViewModel to reduce file size
struct TotalInvestmentQuantityCalculator {

    /// Calculates total investment quantity from investments and price
    /// - Parameters:
    ///   - investments: Array of reserved investments
    ///   - askPrice: Current ask price string (German format)
    ///   - denomination: Optional denomination constraint
    /// - Returns: Calculated quantity respecting denomination rules
    static func calculate(
        investments: [Investment],
        askPrice: String,
        denomination: Int?
    ) -> Int {
        let totalAmount = investments.reduce(0.0) { $0 + $1.amount }

        guard totalAmount > 0 else {
            return 0
        }

        // Parse ask price from German format
        let normalizedPrice = askPrice.replacingOccurrences(of: ",", with: ".")
        guard let price = Double(normalizedPrice), price > 0 else {
            return 0
        }

        // Calculate simple quantity: amount / price (round down)
        let simpleQuantity = totalAmount / price
        var quantity = Int(simpleQuantity)

        // Apply denomination constraint if specified
        if let denomination = denomination, denomination > 0 {
            quantity = (quantity / denomination) * denomination
        }

        return quantity
    }
}











