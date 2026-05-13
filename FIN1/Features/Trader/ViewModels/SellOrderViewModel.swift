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

    // Automatic limit order monitoring
    @Published var isMonitoringLimitOrder: Bool = false
    private var limitOrderMonitor: SellOrderMonitorImpl?

    // MARK: - Order Type
    // Note: OrderMode enum moved to Shared/Models/OrderModels.swift to eliminate duplication

    // MARK: - Properties
    let holding: DepotHolding
    private let traderService: any TraderServiceProtocol
    private let userService: (any UserServiceProtocol)?
    private nonisolated(unsafe) var cancellables = Set<AnyCancellable>()
    private nonisolated(unsafe) var timerCancellable: AnyCancellable?

    // MARK: - Current Trader ID
    /// Returns the current trader's ID from the user service
    private var currentTraderId: String {
        self.userService?.currentUser?.id ?? "unknown_trader"
    }

    // MARK: - Computed Properties
    var currentPrice: Double {
        // Use the current bid price (updated via reloadPrice)
        return self.currentBidPrice > 0 ? self.currentBidPrice : self.holding.currentPrice
    }

    var maxQuantity: Int {
        return self.holding.remainingQuantity
    }

    var quantity: Int {
        return OrderCalculationUtility.parseGermanQuantity(self.quantityText)
    }

    private var isQuantityInValidSteps: Bool {
        guard let denomination = enforcedQuantityDenomination else { return true }
        let currentQuantity = self.quantity
        guard currentQuantity > 0 else { return true }
        return currentQuantity % denomination == 0
    }

    // Current price as Double for limit order comparisons
    var currentPriceValue: Double {
        return self.currentBidPrice > 0 ? self.currentBidPrice : self.holding.currentPrice
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

        // For limit orders, ensure the limit price is reasonable (not higher than current market price for sell orders)
        let hasReasonableLimitPrice = self.orderMode == .market ||
            (self.orderMode == .limit && self.limitPrice != nil && (self.limitPrice ?? 0) <= self.currentPrice)

        // Check if price data is still valid (not expired)
        let hasValidPrice = self.priceValidityProgress > 0

        let isValid = hasValidQuantity && hasValidOrderMode && hasReasonableLimitPrice && hasValidPrice && respectsDenomination

        // Debug logging
        print(
            "🔍 DEBUG: canPlaceOrder validation - quantity: \(self.quantity), maxQuantity: \(self.maxQuantity), orderMode: \(self.orderMode), limitPrice: \(self.limitPrice ?? 0), currentPrice: \(self.currentPrice), priceValidityProgress: \(self.priceValidityProgress), hasValidQuantity: \(hasValidQuantity), respectsDenomination: \(respectsDenomination), hasValidOrderMode: \(hasValidOrderMode), hasReasonableLimitPrice: \(hasReasonableLimitPrice), hasValidPrice: \(hasValidPrice), isValid: \(isValid)"
        )

        return isValid
    }

    // MARK: - Initialization
    init(holding: DepotHolding, traderService: any TraderServiceProtocol, userService: (any UserServiceProtocol)? = nil) {
        self.holding = holding
        self.traderService = traderService
        self.userService = userService

        // Set default quantity to all remaining shares
        self.quantityText = String(holding.remainingQuantity)

        // Initialize current bid price with holding's geldKurs
        self.currentBidPrice = holding.currentPrice

        // Initialize the limit order monitor
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
        // Clean up Combine subscriptions and timers to prevent retain cycles
        cancellables.removeAll()
        timerCancellable?.cancel()
        print("🧹 SellOrderViewModel deallocated")
    }

    // MARK: - Setup
    private func setupBindings() {
        Publishers.orderCalculation(
            quantityText: self.$quantityText.eraseToAnyPublisher(),
            orderMode: self.$orderMode.eraseToAnyPublisher(),
            limitText: self.$limit.eraseToAnyPublisher(),
            marketPrice: self.$currentBidPrice.eraseToAnyPublisher(),
            isSellOrder: true
        )
        .assign(to: \.estimatedProceeds, on: self)
        .store(in: &self.cancellables)

        // Error message validation (without auto-correction to avoid jerky behavior)
        self.$quantityText
            .map { [weak self] text in
                guard let self = self else { return "" }
                let enteredQuantity = OrderCalculationUtility.parseGermanQuantity(text)

                if text.isEmpty {
                    return "" // No error when field is empty
                } else if enteredQuantity <= 0 {
                    return "Please enter a valid quantity"
                } else if enteredQuantity > self.maxQuantity {
                    return "Current holdings: \(self.maxQuantity.formattedAsLocalizedInteger()) shares"
                } else if let denomination = self.enforcedQuantityDenomination,
                          enteredQuantity % denomination != 0 {
                    return self.constraintMessage(for: denomination)
                } else {
                    return "" // Valid quantity
                }
            }
            .assign(to: \.quantityErrorMessage, on: self)
            .store(in: &self.cancellables)
    }

    // MARK: - Public Methods
    func validateAndCorrectQuantity() {
        let enteredQuantity = OrderCalculationUtility.parseGermanQuantity(self.quantityText)

        // Auto-correct if quantity exceeds maximum
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

    func placeOrder() async {
        print("🔘 DEBUG: placeOrder called - canPlaceOrder: \(self.canPlaceOrder)")

        guard self.canPlaceOrder else {
            print("❌ DEBUG: Order validation failed")
            await MainActor.run {
                self.errorMessage = "Bitte überprüfen Sie Ihre Eingaben"
                self.showError = true
            }
            return
        }

        print("✅ DEBUG: Order validation passed, proceeding with order creation")

        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        do {
            let order = self.createSellOrder()
            print("📤 DEBUG: Submitting order to trader service")
            try await self.traderService.submitOrder(order)
            print("✅ DEBUG: Order submitted successfully")
            await MainActor.run {
                self.isLoading = false
                // Trigger navigation to depot view for successful order placement
                self.shouldShowDepotView = true
            }
        } catch {
            print("❌ DEBUG: Order submission failed with error: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
                let appError = error.toAppError()
                self.errorMessage = "Fehler beim Platzieren der Order: \(appError.errorDescription ?? "An error occurred")"
                self.showError = true
            }
        }
    }

    // MARK: - Quantity Constraint Helpers

    private func constraintMessage(for denomination: Int) -> String {
        let ratioText = self.formattedSubscriptionRatio ?? "-"
        return "Zeichnungsverhältnis \(ratioText) → Eingaben nur in \(denomination)-Schritten."
    }

    private var formattedSubscriptionRatio: String? {
        guard let ratio = effectiveSubscriptionRatio else { return nil }
        let formatter = NumberFormatter.localizedDecimalFormatter
        return formatter.string(from: NSNumber(value: ratio))
    }

    private var enforcedQuantityDenomination: Int? {
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

    /// Determines the effective subscription ratio for this holding, including fallbacks
    /// for legacy holdings where ratio/denomination might not be persisted.
    private var effectiveSubscriptionRatio: Double? {
        if let ratio = holding.subscriptionRatio, ratio > 0 {
            return ratio
        }

        if let denomination = holding.denomination, denomination > 0 {
            return 1.0 / Double(denomination)
        }

        // Legacy/backfill: For options/warrants without stored subscription data,
        // assume a typical warrant subscription ratio to align with search hitlist behavior.
        if self.holding.direction != nil {
            return 0.01
        }

        return nil
    }

    // MARK: - Private Methods
    private func createSellOrder() -> OrderSell {
        let orderPrice = self.orderMode == .market ? self.currentPrice : (self.limitPrice ?? self.currentPrice)
        print(
            "🔧 DEBUG: Creating sell order with quantity: \(self.quantity), orderMode: \(self.orderMode), orderPrice: \(orderPrice), limitPrice: \(self.limitPrice ?? 0), totalAmount: \(self.estimatedProceeds)"
        )
        print("🔧 DEBUG: Holding orderId: \(self.holding.orderId ?? "nil"), wkn: \(self.holding.wkn)")
        print("🔧 DEBUG: Using traderId: \(self.currentTraderId)")

        return OrderSell(
            id: UUID().uuidString,
            traderId: self.currentTraderId, // Use actual logged-in trader ID
            symbol: self.holding.wkn,
            description: self.holding.designation,
            quantity: Double(self.quantity),
            price: orderPrice,
            totalAmount: self.estimatedProceeds,
            status: .submitted,
            createdAt: Date(),
            executedAt: nil,
            confirmedAt: nil,
            updatedAt: Date(),
            optionDirection: self.holding.direction,
            underlyingAsset: self.holding.underlyingAsset,
            wkn: self.holding.wkn,
            category: nil, // TODO: Set category from holding
            strike: self.holding.strike,
            orderInstruction: self.orderMode == .market ? "market" : "limit",
            limitPrice: self.limitPrice,
            originalHoldingId: self.holding.orderId
        )
    }

    func reloadPrice() {
        // Simulate price update by a small random amount
        let changeFactor = Double.random(in: 0.98...1.02) // +/- 2% for more realistic variation
        let newPrice = self.holding.currentPrice * changeFactor

        // Update the current bid price
        self.currentBidPrice = newPrice

        // Start price validity timer
        self.startPriceValidityTimer()

        // Start limit order monitoring when user manually refreshes price
        // This gives user control over when automatic monitoring begins
        if self.orderMode == .limit, let price = limitPrice, price > 0, !isMonitoringLimitOrder {
            print("🔄 User manually refreshed price - starting automatic limit order monitoring")
            startLimitOrderMonitoring()
        }
    }

    func startPriceValidityTimer() {
        // Cancel any existing timer first
        self.timerCancellable?.cancel()
        self.priceValidityProgress = 1.0

        self.timerCancellable = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }

                let decrement = 0.05 / 5.0 // 5 seconds duration
                self.priceValidityProgress -= decrement

                if self.priceValidityProgress <= 0 {
                    self.priceValidityProgress = 0
                    self.timerCancellable?.cancel()
                }
            }

        // Store the timer cancellable to manage its lifecycle
        self.timerCancellable?.store(in: &self.cancellables)
    }

    // MARK: - Private Methods
    // Note: calculateEstimatedProceeds() method removed - now using shared OrderCalculationUtility
}

// MARK: - Extensions
extension SellOrderViewModel {
    var formattedCurrentPrice: String {
        return self.currentPrice.formattedAsLocalizedCurrency()
    }

    var formattedEstimatedProceeds: String {
        return self.estimatedProceeds.formattedAsLocalizedCurrency()
    }

    var formattedMaxQuantity: String {
        return self.maxQuantity.formattedAsLocalizedInteger()
    }

    // MARK: - Automatic Limit Order Monitoring

    func startLimitOrderMonitoring() {
        self.limitOrderMonitor?.startLimitOrderMonitoring()
    }

    func stopLimitOrderMonitoring() {
        self.limitOrderMonitor?.stopLimitOrderMonitoring()
    }

    // MARK: - Limit Price Management

    /// Called when the user changes the limit price input
    /// Does NOT start automatic monitoring - user must manually refresh price to start monitoring
    func onLimitPriceChanged() {
        // Stop any existing monitoring when limit price changes
        if self.isMonitoringLimitOrder {
            print("🛑 Limit price changed - stopping automatic monitoring")
            self.stopLimitOrderMonitoring()
        }

        // Do NOT start monitoring automatically - wait for user to refresh price
        print("💰 Limit price changed to: \(self.limit) - waiting for user to refresh price to start monitoring")
    }
}
