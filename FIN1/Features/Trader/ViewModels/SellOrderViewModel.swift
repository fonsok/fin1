import Combine
import Foundation
import SwiftUI

// MARK: - Sell Order ViewModel
/// Manages the state and logic for placing a sell order
@MainActor
final class SellOrderViewModel: ObservableObject, LimitOrderMonitor {

    // MARK: - Published Properties
    @Published var quantityText: String = ""
    @Published var orderMode: OrderMode = .market
    @Published var limit: String = ""
    @Published var estimatedProceeds: Double = 0.0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var currentBidPrice: Double = 0.0
    @Published var priceValidityProgress: Double = 1.0
    @Published var quantityErrorMessage: String?
    @Published var shouldShowDepotView: Bool = false
    @Published var isMonitoringLimitOrder: Bool = false

    // MARK: - Properties
    let holding: DepotHolding
    let traderService: any TraderServiceProtocol
    let userService: (any UserServiceProtocol)?
    let maxPartialSells: Int
    var limitOrderMonitor: SellOrderMonitorImpl?
    nonisolated(unsafe) var cancellables = Set<AnyCancellable>()
    nonisolated(unsafe) var timerCancellable: AnyCancellable?

    // MARK: - Computed Properties
    var currentPrice: Double {
        self.currentBidPrice > 0 ? self.currentBidPrice : self.holding.currentPrice
    }

    var maxQuantity: Int {
        self.holding.remainingQuantity
    }

    var quantity: Int {
        OrderCalculationUtility.parseGermanQuantity(self.quantityText)
    }

    var currentPriceValue: Double {
        self.currentBidPrice > 0 ? self.currentBidPrice : self.holding.currentPrice
    }

    var limitPrice: Double? {
        guard self.orderMode == .limit, !self.limit.isEmpty else { return nil }
        return OrderCalculationUtility.parseGermanPrice(self.limit)
    }

    var canPlaceOrder: Bool {
        let hasValidQuantity = self.quantity > 0 && self.quantity <= self.maxQuantity
        let respectsDenomination = self.isQuantityInValidSteps
        let hasValidOrderMode = self.orderMode == .market || (
            self.orderMode == .limit && self.limitPrice != nil && (self.limitPrice ?? 0) > 0
        )
        let hasReasonableLimitPrice = self.orderMode == .market ||
            (self.orderMode == .limit && self.limitPrice != nil && (self.limitPrice ?? 0) <= self.currentPrice)
        let hasValidPrice = self.priceValidityProgress > 0
        let isValid = hasValidQuantity && hasValidOrderMode && hasReasonableLimitPrice && hasValidPrice && respectsDenomination

        #if DEBUG
        print(
            "🔍 DEBUG: canPlaceOrder validation - quantity: \(self.quantity), maxQuantity: \(self.maxQuantity), orderMode: \(self.orderMode), limitPrice: \(self.limitPrice ?? 0), currentPrice: \(self.currentPrice), priceValidityProgress: \(self.priceValidityProgress), hasValidQuantity: \(hasValidQuantity), respectsDenomination: \(respectsDenomination), hasValidOrderMode: \(hasValidOrderMode), hasReasonableLimitPrice: \(hasReasonableLimitPrice), hasValidPrice: \(hasValidPrice), isValid: \(isValid)"
        )
        #endif

        return isValid
    }

    // MARK: - Initialization
    init(
        holding: DepotHolding,
        traderService: any TraderServiceProtocol,
        userService: (any UserServiceProtocol)? = nil,
        maxPartialSells: Int = 3
    ) {
        self.holding = holding
        self.traderService = traderService
        self.userService = userService
        self.maxPartialSells = maxPartialSells
        self.quantityText = String(holding.remainingQuantity)
        self.currentBidPrice = holding.currentPrice
        self.limitOrderMonitor = SellOrderMonitorImpl(sellOrderViewModel: self)

        self.setupBindings()
        self.reloadPrice()

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-prefill-limit-order") {
            self.quantityText = "100"
            self.orderMode = .limit
            self.limit = "0,50"
        }
        #endif
    }

    deinit {
        cancellables.removeAll()
        timerCancellable?.cancel()
        #if DEBUG
        print("🧹 SellOrderViewModel deallocated")
        #endif
    }
}
