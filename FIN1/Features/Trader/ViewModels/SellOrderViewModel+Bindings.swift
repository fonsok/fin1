import Combine
import Foundation

extension SellOrderViewModel {

    func setupBindings() {
        Publishers.orderCalculation(
            quantityText: self.$quantityText.eraseToAnyPublisher(),
            orderMode: self.$orderMode.eraseToAnyPublisher(),
            limitText: self.$limit.eraseToAnyPublisher(),
            marketPrice: self.$currentBidPrice.eraseToAnyPublisher(),
            isSellOrder: true
        )
        .assign(to: \.estimatedProceeds, on: self)
        .store(in: &self.cancellables)

        self.$quantityText
            .map { [weak self] text in
                guard let self else { return "" }
                let enteredQuantity = OrderCalculationUtility.parseGermanQuantity(text)

                if text.isEmpty {
                    return ""
                } else if enteredQuantity <= 0 {
                    return "Please enter a valid quantity"
                } else if enteredQuantity > self.maxQuantity {
                    return "Current holdings: \(self.maxQuantity.formattedAsLocalizedInteger()) shares"
                } else if let denomination = self.enforcedQuantityDenomination,
                          enteredQuantity % denomination != 0 {
                    return self.constraintMessage(for: denomination)
                } else {
                    return ""
                }
            }
            .assign(to: \.quantityErrorMessage, on: self)
            .store(in: &self.cancellables)
    }
}
