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
        let orderPrice = self.orderMode == .market ? self.currentPrice : (self.limitPrice ?? self.currentPrice)
        return Double(self.quantity) * orderPrice
    }

    var maxQuantity: Int {
        Int(self.holding.remainingQuantity)
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
        guard self.quantity > 0 && self.quantity <= self.maxQuantity else {
            self.errorMessage = "Invalid quantity"
            return
        }

        self.isLoading = true
        self.errorMessage = nil

        do {
            let orderPrice = self.orderMode == .market ? self.currentPrice : (self.limitPrice ?? self.currentPrice)

            let request = SellOrderRequest(
                symbol: holding.wkn,
                quantity: self.quantity,
                price: orderPrice,
                optionDirection: self.holding.direction,
                description: self.holding.designation,
                orderInstruction: self.orderMode == .market ? "market" : "limit",
                limitPrice: self.limitPrice,
                strike: self.holding.strike,
                originalHoldingId: self.holding.orderId
            )

            _ = try await self.orderService.placeSellOrder(request)

            // Success - navigate to depot view
            self.shouldShowDepotView = true

        } catch {
            let appError = error.toAppError()
            self.errorMessage = appError.errorDescription ?? "An error occurred"
        }

        self.isLoading = false
    }

    func reloadPrice() {
        // Simulate price update
        let priceChange = Double.random(in: -0.05...0.05)
        self.currentPrice = max(0.01, self.currentPrice + priceChange)
    }

    func updateQuantity(_ newQuantity: Int) {
        self.quantity = max(1, min(newQuantity, self.maxQuantity))
    }

    func setOrderMode(_ mode: OrderMode) {
        self.orderMode = mode
        if mode == .market {
            self.limitPrice = nil
        }
    }

    func setLimitPrice(_ price: Double?) {
        self.limitPrice = price
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
        let orderPrice = self.orderMode == .market ? self.currentPrice : (self.limitPrice ?? self.currentPrice)
        return Double(self.quantity) * orderPrice
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
        guard self.quantity > 0 else {
            self.errorMessage = "Invalid quantity"
            return
        }

        self.isLoading = true
        self.errorMessage = nil

        do {
            let orderPrice = self.orderMode == .market ? self.currentPrice : (self.limitPrice ?? self.currentPrice)

            let request = BuyOrderRequest(
                symbol: searchResult.wkn,
                quantity: self.quantity,
                price: orderPrice,
                optionDirection: self.searchResult.direction,
                description: self.searchResult.underlyingAsset,
                orderInstruction: self.orderMode == .market ? "market" : "limit",
                limitPrice: self.limitPrice,
                strike: Double(self.searchResult.strike.replacingOccurrences(of: ",", with: ".")),
                subscriptionRatio: self.searchResult.subscriptionRatio,
                denomination: self.searchResult.denomination
            )

            _ = try await self.orderService.placeBuyOrder(request)

            // Success - navigate to depot view
            self.shouldShowDepotView = true

        } catch {
            let appError = error.toAppError()
            self.errorMessage = appError.errorDescription ?? "An error occurred"
        }

        self.isLoading = false
    }

    func reloadPrice() {
        // Simulate price update
        let priceChange = Double.random(in: -0.05...0.05)
        self.currentPrice = max(0.01, self.currentPrice + priceChange)
    }

    func updateQuantity(_ newQuantity: Int) {
        self.quantity = max(1, newQuantity)
    }

    func setOrderMode(_ mode: OrderMode) {
        self.orderMode = mode
        if mode == .market {
            self.limitPrice = nil
        }
    }

    func setLimitPrice(_ price: Double?) {
        self.limitPrice = price
    }
}
