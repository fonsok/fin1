import Foundation

extension SellOrderViewModel {

    var isQuantityInValidSteps: Bool {
        guard let denomination = enforcedQuantityDenomination else { return true }
        let currentQuantity = self.quantity
        guard currentQuantity > 0 else { return true }
        return currentQuantity % denomination == 0
    }

    func validateAndCorrectQuantity() {
        if self.mustSellFullRemaining {
            self.quantityText = String(self.maxQuantity)
            return
        }

        let enteredQuantity = OrderCalculationUtility.parseGermanQuantity(self.quantityText)

        if !self.quantityText.isEmpty && enteredQuantity > self.maxQuantity {
            self.quantityText = String(self.maxQuantity)
        }

        guard let denomination = enforcedQuantityDenomination, enteredQuantity > 0 else {
            return
        }

        let remainder = enteredQuantity % denomination
        if remainder != 0 {
            let adjustedQuantity = enteredQuantity - remainder
            self.quantityText = adjustedQuantity > 0 ? String(adjustedQuantity) : ""
        }
    }

    func constraintMessage(for denomination: Int) -> String {
        let ratioText = self.formattedSubscriptionRatio ?? "-"
        return "Zeichnungsverhältnis \(ratioText) → Eingaben nur in \(denomination)-Schritten."
    }

    var formattedSubscriptionRatio: String? {
        guard let ratio = effectiveSubscriptionRatio else { return nil }
        let formatter = NumberFormatter.localizedDecimalFormatter
        return formatter.string(from: NSNumber(value: ratio))
    }

    var enforcedQuantityDenomination: Int? {
        if let explicitDenomination = holding.denomination, explicitDenomination > 1 {
            return self.maxQuantity % explicitDenomination == 0 ? explicitDenomination : nil
        }

        guard let ratio = effectiveSubscriptionRatio else {
            return nil
        }

        guard let defaultDenomination = CalculationConstants.SecurityDenominations
            .defaultDenomination(forSubscriptionRatio: ratio) else {
            return nil
        }

        if defaultDenomination == 10 || defaultDenomination == 100 {
            return self.maxQuantity % defaultDenomination == 0 ? defaultDenomination : nil
        }

        return nil
    }

    var effectiveSubscriptionRatio: Double? {
        if let ratio = holding.subscriptionRatio, ratio > 0 {
            return ratio
        }

        if let denomination = holding.denomination, denomination > 0 {
            return 1.0 / Double(denomination)
        }

        if self.holding.direction != nil {
            return 0.01
        }

        return nil
    }
}
