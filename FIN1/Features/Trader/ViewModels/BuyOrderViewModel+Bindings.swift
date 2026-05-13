import Combine
import Foundation

extension BuyOrderViewModel {

    func setupBindings() {
        $quantityText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .map { [weak self] text -> (value: Double?, message: String?) in
                guard let self = self else { return (0.0, nil) }
                let processedValue = self.quantityInputManager.processQuantityText(text)
                return self.quantityConstraintHelper.evaluateQuantityConstraints(for: processedValue)
            }
            .handleEvents(receiveOutput: { [weak self] result in
                self?.quantityConstraintMessage = result.message
            })
            .compactMap { $0.value }
            .assign(to: \.quantity, on: self)
            .store(in: &cancellables)

        $quantityText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                _ = self.quantityInputManager.processQuantityText(text)
                self.showMaxValueWarning = self.quantityInputManager.showMaxValueWarning
            }
            .store(in: &cancellables)

        $quantity
            .map { NumberFormatter.localizedIntegerFormatter.string(from: NSNumber(value: $0)) ?? "\(Int($0))" }
            .assign(to: \.quantityText, on: self)
            .store(in: &cancellables)

        Publishers.orderCalculation(
            quantityText: $quantityText.eraseToAnyPublisher(),
            orderMode: $orderMode.eraseToAnyPublisher(),
            limitText: $limit.eraseToAnyPublisher(),
            marketPrice: $searchResult.map {
                Double($0.askPrice.replacingOccurrences(of: ",", with: ".")) ?? 0.0
            }.eraseToAnyPublisher(),
            isSellOrder: false
        )
        .assign(to: \.estimatedCost, on: self)
        .store(in: &cancellables)

        $estimatedCost
            .sink { [weak self] _ in
                self?.updateInsufficientFundsWarning()
                Task { @MainActor [weak self] in
                    await self?.checkTransactionLimits()
                }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest($quantity, $searchResult)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    await self?.calculateInvestmentOrder()
                }
            }
            .store(in: &cancellables)
    }
}
