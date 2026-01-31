import Foundation
import SwiftUI

// MARK: - Simplified Sell Order ViewModel
/// Simplified ViewModel using the unified order service and state manager
@MainActor
final class SimplifiedSellOrderViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var quantity: Int = 1
    @Published var orderMode: OrderMode = .market
    @Published var limitPrice: Double?
    @Published var currentPrice: Double
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var shouldShowDepotView = false

    // MARK: - Computed Properties
    var estimatedProceeds: Double {
        let orderPrice = orderMode == .market ? currentPrice : (limitPrice ?? currentPrice)
        return Double(quantity) * orderPrice
    }

    var maxQuantity: Int {
        Int(holding.remainingQuantity)
    }

    // MARK: - Dependencies
    private let orderService: any UnifiedOrderServiceProtocol
    private let stateStore: any TradingStateStoreProtocol
    private let holding: DepotHolding

    // MARK: - Initialization
    init(
        holding: DepotHolding,
        orderService: any UnifiedOrderServiceProtocol,
        stateStore: any TradingStateStoreProtocol
    ) {
        self.holding = holding
        self.orderService = orderService
        self.stateStore = stateStore
        self.currentPrice = holding.currentPrice
    }

    // MARK: - Public Methods
    func placeOrder() async {
        guard quantity > 0 && quantity <= maxQuantity else {
            errorMessage = "Invalid quantity"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let orderPrice = orderMode == .market ? currentPrice : (limitPrice ?? currentPrice)

            let request = SellOrderRequest(
                symbol: holding.wkn,
                quantity: quantity,
                price: orderPrice,
                optionDirection: holding.direction,
                description: holding.designation,
                orderInstruction: orderMode == .market ? "market" : "limit",
                limitPrice: limitPrice,
                strike: holding.strike,
                originalHoldingId: holding.orderId
            )

            _ = try await orderService.placeSellOrder(request)

            // Success - navigate to depot view
            shouldShowDepotView = true

        } catch {
            let appError = error.toAppError()
            errorMessage = appError.errorDescription ?? "An error occurred"
        }

        isLoading = false
    }

    func reloadPrice() {
        // Simulate price update
        let priceChange = Double.random(in: -0.05...0.05)
        currentPrice = max(0.01, currentPrice + priceChange)
    }

    func updateQuantity(_ newQuantity: Int) {
        quantity = max(1, min(newQuantity, maxQuantity))
    }

    func setOrderMode(_ mode: OrderMode) {
        orderMode = mode
        if mode == .market {
            limitPrice = nil
        }
    }

    func setLimitPrice(_ price: Double?) {
        limitPrice = price
    }
}

// MARK: - Order Mode Enum (using existing one from NewBuyOrderViewModel)

// MARK: - Simplified Buy Order ViewModel
@MainActor
final class SimplifiedBuyOrderViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var quantity: Int = 1
    @Published var orderMode: OrderMode = .market
    @Published var limitPrice: Double?
    @Published var currentPrice: Double
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var shouldShowDepotView = false

    // MARK: - Computed Properties
    var estimatedCost: Double {
        let orderPrice = orderMode == .market ? currentPrice : (limitPrice ?? currentPrice)
        return Double(quantity) * orderPrice
    }

    // MARK: - Dependencies
    private let orderService: any UnifiedOrderServiceProtocol
    private let stateStore: any TradingStateStoreProtocol
    private let searchResult: SearchResult

    // MARK: - Initialization
    init(
        searchResult: SearchResult,
        orderService: any UnifiedOrderServiceProtocol,
        stateStore: any TradingStateStoreProtocol
    ) {
        self.searchResult = searchResult
        self.orderService = orderService
        self.stateStore = stateStore
        self.currentPrice = Double(searchResult.askPrice.replacingOccurrences(of: ",", with: ".")) ?? 0.0
    }

    // MARK: - Public Methods
    func placeOrder() async {
        guard quantity > 0 else {
            errorMessage = "Invalid quantity"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let orderPrice = orderMode == .market ? currentPrice : (limitPrice ?? currentPrice)

            let request = BuyOrderRequest(
                symbol: searchResult.wkn,
                quantity: quantity,
                price: orderPrice,
                optionDirection: searchResult.direction,
                description: searchResult.underlyingAsset,
                orderInstruction: orderMode == .market ? "market" : "limit",
                limitPrice: limitPrice,
                strike: Double(searchResult.strike.replacingOccurrences(of: ",", with: ".")),
                subscriptionRatio: searchResult.subscriptionRatio,
                denomination: searchResult.denomination
            )

            _ = try await orderService.placeBuyOrder(request)

            // Success - navigate to depot view
            shouldShowDepotView = true

        } catch {
            let appError = error.toAppError()
            errorMessage = appError.errorDescription ?? "An error occurred"
        }

        isLoading = false
    }

    func reloadPrice() {
        // Simulate price update
        let priceChange = Double.random(in: -0.05...0.05)
        currentPrice = max(0.01, currentPrice + priceChange)
    }

    func updateQuantity(_ newQuantity: Int) {
        quantity = max(1, newQuantity)
    }

    func setOrderMode(_ mode: OrderMode) {
        orderMode = mode
        if mode == .market {
            limitPrice = nil
        }
    }

    func setLimitPrice(_ price: Double?) {
        limitPrice = price
    }
}
