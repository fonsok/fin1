import Combine
import Foundation

// MARK: - Simplified Buy Order ViewModel
/// Clean, simple ViewModel for buy orders using the simplified architecture

enum NewBuyOrderStatus: Equatable {
    case idle
    case transmitting
    case orderPlaced(executedPrice: Double, finalCost: Double)
    case failed(AppError)
}

// Note: OrderMode enum moved to Shared/Models/OrderModels.swift to eliminate duplication

@MainActor
final class NewBuyOrderViewModel: ObservableObject {
    @Published var searchResult: SearchResult
    @Published var quantity: Double = 1_000
    @Published var quantityText: String = "1.000"
    @Published var orderMode: OrderMode = .market
    @Published var limit: String = ""
    @Published var estimatedCost: Double = 0.0
    @Published var orderStatus: NewBuyOrderStatus = .idle
    @Published var showMaxValueWarning: Bool = false
    @Published var shouldShowDepotView: Bool = false

    private let orderService: any NewOrderServiceProtocol

    init(searchResult: SearchResult, orderService: any NewOrderServiceProtocol) {
        self.searchResult = searchResult
        self.orderService = orderService
        self.updateEstimatedCost()
    }

    // MARK: - Computed Properties
    var currentPriceValue: Double {
        let normalizedString = self.searchResult.askPrice.replacingOccurrences(of: ",", with: ".")
        return Double(normalizedString) ?? 0.0
    }

    var executedPrice: Double {
        switch self.orderMode {
        case .market:
            return self.currentPriceValue
        case .limit:
            let normalizedLimit = self.limit.replacingOccurrences(of: ",", with: ".")
            return Double(normalizedLimit) ?? self.currentPriceValue
        }
    }

    var finalCost: Double {
        return self.quantity * self.executedPrice
    }

    // MARK: - Actions
    func placeOrder() async {
        self.orderStatus = .transmitting

        do {
            let orderRequest = NewBuyOrderRequest(
                symbol: searchResult.wkn,
                quantity: Int(self.quantity),
                price: self.executedPrice,
                optionDirection: self.searchResult.direction,
                description: self.searchResult.underlyingAsset,
                orderInstruction: self.orderMode.rawValue,
                limitPrice: self.orderMode == .limit ? Double(self.limit.replacingOccurrences(of: ",", with: ".")) : nil,
                strike: Double(self.searchResult.strike.replacingOccurrences(of: ",", with: "."))
            )

            _ = try await self.orderService.placeBuyOrder(orderRequest)

            self.orderStatus = .orderPlaced(executedPrice: self.executedPrice, finalCost: self.finalCost)
            self.shouldShowDepotView = true

        } catch {
            self.orderStatus = .failed(error as? AppError ?? AppError.unknown("Unknown error occurred"))
        }
    }

    func updateQuantity(_ newValue: Double) {
        self.quantity = newValue
        self.quantityText = newValue.formattedAsLocalizedNumber()
        self.updateEstimatedCost()
    }

    func updateQuantityText(_ newText: String) {
        self.quantityText = newText
        let normalizedText = newText.replacingOccurrences(of: ",", with: ".")
        if let newValue = Double(normalizedText) {
            self.quantity = newValue
            self.updateEstimatedCost()
        }
    }

    func updateOrderMode(_ mode: OrderMode) {
        self.orderMode = mode
        self.updateEstimatedCost()
    }

    func updateLimit(_ newLimit: String) {
        self.limit = newLimit
        self.updateEstimatedCost()
    }

    // MARK: - Private Methods
    private func updateEstimatedCost() {
        self.estimatedCost = self.quantity * self.executedPrice
    }
}
