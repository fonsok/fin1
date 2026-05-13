import Combine
import Foundation

// MARK: - Buy Order Setup Coordinator Protocol
@MainActor
protocol BuyOrderSetupCoordinatorProtocol {
    func setupBindings(
        quantityText: Published<String>.Publisher,
        quantity: Published<Double>.Publisher,
        orderMode: Published<OrderMode>.Publisher,
        limit: Published<String>.Publisher,
        searchResult: Published<SearchResult>.Publisher,
        estimatedCost: Published<Double>.Publisher,
        quantityInputManager: QuantityInputManager,
        onQuantityChanged: @escaping () -> Void,
        onCostChanged: @escaping () -> Void
    ) -> Set<AnyCancellable>
}

// MARK: - Buy Order Setup Coordinator
/// Handles Combine binding setup and coordination for buy orders
@MainActor
final class BuyOrderSetupCoordinator: BuyOrderSetupCoordinatorProtocol {

    func setupBindings(
        quantityText: Published<String>.Publisher,
        quantity: Published<Double>.Publisher,
        orderMode: Published<OrderMode>.Publisher,
        limit: Published<String>.Publisher,
        searchResult: Published<SearchResult>.Publisher,
        estimatedCost: Published<Double>.Publisher,
        quantityInputManager: QuantityInputManager,
        onQuantityChanged: @escaping () -> Void,
        onCostChanged: @escaping () -> Void
    ) -> Set<AnyCancellable> {
        var cancellables = Set<AnyCancellable>()

        // Quantity text binding
        quantityText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .map { text in
                quantityInputManager.processQuantityText(text)
            }
            .sink { _ in
                // This will be handled by the ViewModel's quantity property setter
            }
            .store(in: &cancellables)

        // Quantity binding (format quantity to text)
        quantity
            .map { value in
                let formatter = NumberFormatter.localizedIntegerFormatter
                return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
            }
            .sink { _ in
                // This will be handled by the ViewModel's quantityText property setter
            }
            .store(in: &cancellables)

        // Cost calculation
        Publishers.orderCalculation(
            quantityText: quantityText.eraseToAnyPublisher(),
            orderMode: orderMode.eraseToAnyPublisher(),
            limitText: limit.eraseToAnyPublisher(),
            marketPrice: searchResult.map {
                Double($0.askPrice.replacingOccurrences(of: ",", with: ".")) ?? 0.0
            }.eraseToAnyPublisher(),
            isSellOrder: false
        )
        .sink { _ in
            onCostChanged()
        }
        .store(in: &cancellables)

        // Recalculate investment order when quantity or price changes
        Publishers.CombineLatest(quantity, searchResult)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { _, _ in
                onQuantityChanged()
            }
            .store(in: &cancellables)

        return cancellables
    }
}
