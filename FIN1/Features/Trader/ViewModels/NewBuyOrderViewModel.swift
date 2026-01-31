import Foundation
import Combine

// MARK: - Simplified Buy Order ViewModel
/// Clean, simple ViewModel for buy orders using the simplified architecture

enum NewBuyOrderStatus: Equatable {
    case idle
    case transmitting
    case orderPlaced(executedPrice: Double, finalCost: Double)
    case failed(AppError)
}

// Note: OrderMode enum moved to Shared/Models/OrderModels.swift to eliminate duplication

final class NewBuyOrderViewModel: ObservableObject {
    @Published var searchResult: SearchResult
    @Published var quantity: Double = 1000
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
        updateEstimatedCost()
    }

    // MARK: - Computed Properties
    var currentPriceValue: Double {
        let normalizedString = searchResult.askPrice.replacingOccurrences(of: ",", with: ".")
        return Double(normalizedString) ?? 0.0
    }

    var executedPrice: Double {
        switch orderMode {
        case .market:
            return currentPriceValue
        case .limit:
            let normalizedLimit = limit.replacingOccurrences(of: ",", with: ".")
            return Double(normalizedLimit) ?? currentPriceValue
        }
    }

    var finalCost: Double {
        return quantity * executedPrice
    }

    // MARK: - Actions
    func placeOrder() async {
        orderStatus = .transmitting

        do {
            let orderRequest = NewBuyOrderRequest(
                symbol: searchResult.wkn,
                quantity: Int(quantity),
                price: executedPrice,
                optionDirection: searchResult.direction,
                description: searchResult.underlyingAsset,
                orderInstruction: orderMode.rawValue,
                limitPrice: orderMode == .limit ? Double(limit.replacingOccurrences(of: ",", with: ".")) : nil,
                strike: Double(searchResult.strike.replacingOccurrences(of: ",", with: "."))
            )

            _ = try await orderService.placeBuyOrder(orderRequest)

            await MainActor.run {
                orderStatus = .orderPlaced(executedPrice: executedPrice, finalCost: finalCost)
                shouldShowDepotView = true
            }

        } catch {
            await MainActor.run {
                orderStatus = .failed(error as? AppError ?? AppError.unknown("Unknown error occurred"))
            }
        }
    }

    func updateQuantity(_ newValue: Double) {
        quantity = newValue
        quantityText = newValue.formattedAsLocalizedNumber()
        updateEstimatedCost()
    }

    func updateQuantityText(_ newText: String) {
        quantityText = newText
        let normalizedText = newText.replacingOccurrences(of: ",", with: ".")
        if let newValue = Double(normalizedText) {
            quantity = newValue
            updateEstimatedCost()
        }
    }

    func updateOrderMode(_ mode: OrderMode) {
        orderMode = mode
        updateEstimatedCost()
    }

    func updateLimit(_ newLimit: String) {
        limit = newLimit
        updateEstimatedCost()
    }

    // MARK: - Private Methods
    private func updateEstimatedCost() {
        estimatedCost = quantity * executedPrice
    }
}
