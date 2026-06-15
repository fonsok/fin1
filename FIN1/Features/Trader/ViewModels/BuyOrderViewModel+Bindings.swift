import Combine
import Foundation

extension BuyOrderViewModel {

    func setupBindings() {
        // Parse quantity from text only — do not write formatted text back while editing
        // (SellOrderViewModel pattern; avoids "1.000" → "1.200" fighting the TextField).
        $quantityText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .map { [weak self] text -> (value: Double?, message: String?) in
                guard let self = self else { return (nil, nil) }
                let parsed = OrderCalculationUtility.parseGermanQuantity(text)
                let processedValue = self.quantityInputManager.processQuantityText(text)
                let effectiveValue = processedValue > 0 ? processedValue : Double(parsed)
                return self.quantityConstraintHelper.evaluateQuantityConstraints(for: effectiveValue)
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
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateInsufficientFundsWarning()
                self.transactionLimitCheckTask?.cancel()
                self.transactionLimitCheckTask = Task { @MainActor [weak self] in
                    await self?.checkTransactionLimits()
                }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(
            $quantityText.debounce(for: .milliseconds(300), scheduler: RunLoop.main),
            $searchResult
        )
        .sink { [weak self] _, _ in
            guard let self else { return }
            self.investmentCalculationTask?.cancel()
            self.investmentCalculationTask = Task { @MainActor [weak self] in
                await self?.calculateInvestmentOrder()
            }
        }
        .store(in: &cancellables)
    }
}
