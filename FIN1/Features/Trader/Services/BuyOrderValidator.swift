import Foundation

// MARK: - Buy Order Validator Protocol
@MainActor
protocol BuyOrderValidatorProtocol {
    func validateLimitPrice(_ limit: String) -> Bool
    func validateOrderPlacement(
        quantity: Double,
        orderMode: OrderMode,
        limit: String,
        priceValidityProgress: Double,
        estimatedCost: Double,
        userService: any UserServiceProtocol,
        cashBalanceService: any CashBalanceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        maxQuantity: Int
    ) -> Bool
}

// MARK: - Buy Order Validator
/// Handles validation logic for buy orders
@MainActor
final class BuyOrderValidator: BuyOrderValidatorProtocol {

    func validateLimitPrice(_ limit: String) -> Bool {
        // Validate German format: only numbers and exactly one comma allowed
        let isValidGermanFormat = limit.allSatisfy { $0.isNumber || $0 == "," } &&
                                 limit.filter { $0 == "," }.count <= 1 &&
                                 !limit.hasPrefix(",") &&
                                 !limit.hasSuffix(",")

        guard isValidGermanFormat else {
            print("🔍 DEBUG: Invalid German format - limit: '\(limit)'")
            return false
        }

        return true
    }

    func validateOrderPlacement(
        quantity: Double,
        orderMode: OrderMode,
        limit: String,
        priceValidityProgress: Double,
        estimatedCost: Double,
        userService: any UserServiceProtocol,
        cashBalanceService: any CashBalanceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        maxQuantity: Int
    ) -> Bool {
        let hasValidQuantity = quantity > 0 && quantity <= Double(maxQuantity)
        let hasValidOrderMode = orderMode == .market || (orderMode == .limit && !limit.isEmpty)

        // For limit orders, validate the limit price format
        let hasValidLimitPrice = orderMode == .market || {
            guard orderMode == .limit, !limit.isEmpty else { return true }
            return validateLimitPrice(limit)
        }()

        // Check if price data is still valid (not expired)
        let hasValidPrice = priceValidityProgress > 0

        // Cash balance validation - ensure estimated balance ≥ minimum reserve
        let hasSufficientFunds: Bool
        if let currentUser = userService.currentUser {
            let minimumReserve = configurationService.getMinimumCashReserve(for: currentUser.id)
            hasSufficientFunds = cashBalanceService.hasSufficientFunds(for: estimatedCost, minimumReserve: minimumReserve)
        } else {
            hasSufficientFunds = false
        }

        let isValid = hasValidQuantity && hasValidOrderMode && hasValidLimitPrice && hasValidPrice && hasSufficientFunds

        // Debug logging
        print("🔍 DEBUG: BuyOrder canPlaceOrder validation - quantity: \(quantity), orderMode: \(orderMode), limit: '\(limit)', priceValidityProgress: \(priceValidityProgress), estimatedCost: €\(estimatedCost.formatted(.currency(code: "EUR"))), hasValidQuantity: \(hasValidQuantity), hasValidOrderMode: \(hasValidOrderMode), hasValidLimitPrice: \(hasValidLimitPrice), hasValidPrice: \(hasValidPrice), hasSufficientFunds: \(hasSufficientFunds), isValid: \(isValid)")

        return isValid
    }
}
