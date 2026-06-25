import Foundation

// MARK: - Brief-Kurs staleness (UX indicator thresholds — not placement gates)

enum BuyOrderPriceStaleness {
    /// Indicator below this value shows an elevated staleness hint in the buy form.
    static let elevatedWarningThreshold: Double = 0.25

    static let possiblyStaleMessage =
        "Der angezeigte Kurs könnte veraltet sein. Für einen aktuellen Stand ↻ tippen."

    static let likelyStaleMessage =
        "Der angezeigte Kurs ist wahrscheinlich veraltet. ↻ neu laden wird empfohlen."
}

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
            #if DEBUG
            print("🔍 DEBUG: Invalid German format - limit: '\(limit)'")
            #endif
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
            return self.validateLimitPrice(limit)
        }()

        // Cash balance validation - ensure estimated balance ≥ minimum reserve
        let hasSufficientFunds: Bool
        if let currentUser = userService.currentUser {
            let minimumReserve = configurationService.getMinimumCashReserve(for: currentUser.id)
            hasSufficientFunds = cashBalanceService.hasSufficientFunds(for: estimatedCost, minimumReserve: minimumReserve)
        } else {
            hasSufficientFunds = false
        }

        // Staleness indicator is advisory only (green → red); it does not gate placement.
        let isValid = hasValidQuantity && hasValidOrderMode && hasValidLimitPrice && hasSufficientFunds

        #if DEBUG
        print(
            "🔍 DEBUG: BuyOrder canPlaceOrder validation - quantity: \(quantity), orderMode: \(orderMode), limit: '\(limit)', priceStalenessProgress: \(priceValidityProgress), estimatedCost: €\(estimatedCost.formatted(.currency(code: "EUR"))), hasValidQuantity: \(hasValidQuantity), hasValidOrderMode: \(hasValidOrderMode), hasValidLimitPrice: \(hasValidLimitPrice), hasSufficientFunds: \(hasSufficientFunds), isValid: \(isValid)"
        )
        #endif

        return isValid
    }
}
