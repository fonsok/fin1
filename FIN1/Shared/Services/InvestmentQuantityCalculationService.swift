import Foundation

// MARK: - Investment Quantity Calculation Service Implementation

/// Service that calculates the maximum purchasable quantity of securities
/// given an investment balance and price per security, accounting for trading fees
final class InvestmentQuantityCalculationService: InvestmentQuantityCalculationServiceProtocol, ServiceLifecycle {
    private lazy var combinedOrderCalculator: CombinedOrderCalculator = {
        CombinedOrderCalculator { [weak self] investmentBalance, pricePerSecurity, denomination, subscriptionRatio, minimumOrderAmount in
            guard let self = self else { return 0 }
            return self.calculateMaxPurchasableQuantity(
                investmentBalance: investmentBalance,
                pricePerSecurity: pricePerSecurity,
                denomination: denomination,
                subscriptionRatio: subscriptionRatio,
                minimumOrderAmount: minimumOrderAmount
            )
        }
    }()

    // MARK: - Public Methods

    /// Calculates the maximum quantity of securities that can be purchased with investment balance
    /// Uses binary search algorithm for efficiency
    /// - Parameters:
    ///   - investmentBalance: Available investment balance in EUR
    ///   - pricePerSecurity: Price per security (share) in EUR
    ///   - denomination: Optional denomination constraint (e.g., 1, 10, 100). If nil, no denomination restriction.
    ///   - subscriptionRatio: Subscription ratio (e.g., 1.0, 0.1, 0.01, 10.0, 100.0). Represents units per share (1:1, 1:10, 1:100). Default is 1.0.
    ///   - minimumOrderAmount: Optional minimum order amount in EUR. If specified, order must meet or exceed this amount.
    /// - Returns: Maximum purchasable quantity in units (integer), rounded down to valid denomination if specified, or 0 if minimum order amount cannot be met
    func calculateMaxPurchasableQuantity(
        investmentBalance: Double,
        pricePerSecurity: Double,
        denomination: Int? = nil,
        subscriptionRatio: Double = 1.0,
        minimumOrderAmount: Double? = nil
    ) -> Int {
        // Validate inputs
        guard investmentBalance > 0, pricePerSecurity > 0, subscriptionRatio > 0 else {
            return 0
        }

        // Calculate price per unit (pricePerSecurity is per share)
        let pricePerUnit = pricePerSecurity / Double(subscriptionRatio)

        // DEBUG: Log price values to diagnose quantity calculation issues
        print("🔍 InvestmentQuantityCalculationService.calculateMaxPurchasableQuantity:")
        print("   💰 investmentBalance: €\(String(format: "%.2f", investmentBalance))")
        print("   💵 pricePerSecurity: €\(String(format: "%.2f", pricePerSecurity))")
        print("   📊 subscriptionRatio: \(subscriptionRatio)")
        print("   💵 pricePerUnit: €\(String(format: "%.2f", pricePerUnit))")

        // Check if investment balance can meet minimum order amount requirement
        if let minimum = minimumOrderAmount, minimum > 0 {
            guard investmentBalance >= minimum else {
                // Investment balance is insufficient to meet minimum order amount
                return 0
            }
        }

        // Calculate maximum possible quantity in units (if no fees)
        let maxPossibleQuantity = Int(investmentBalance / pricePerUnit)
        print("   📈 maxPossibleQuantity (no fees): \(maxPossibleQuantity)")
        guard maxPossibleQuantity > 0 else {
            return 0
        }

        // Calculate minimum quantity required to meet minimum order amount (in units)
        let minRequiredQuantity = CalculationConstants.SecurityDenominations.calculateMinimumQuantity(
            pricePerSecurity: pricePerUnit,
            minimumOrderAmount: nil // Don't apply minimum to investment portion individually
        )

        // If minimum quantity is required, ensure we start from at least that quantity
        guard maxPossibleQuantity >= minRequiredQuantity else {
            return 0 // Cannot meet minimum order amount
        }

        // Apply denomination constraint to upper bound if specified
        let upperBound: Int
        if let denomination = denomination {
            upperBound = CalculationConstants.SecurityDenominations.roundDownToDenomination(
                maxPossibleQuantity,
                denominations: [denomination]
            )
            guard upperBound > 0 else {
                return 0
            }
        } else {
            upperBound = maxPossibleQuantity
        }

        // Use binary search to find optimal quantity
        // If denomination is specified, we need to search in denomination steps
        if let denomination = denomination {
            // Start from minimum required quantity or denomination, whichever is larger
            let startQuantity = max(minRequiredQuantity, denomination)

            // Search in denomination increments
            var bestQuantity = 0
            var testQuantity = startQuantity

            while testQuantity <= upperBound {
                // Calculate order amount: units × price per unit
                let orderAmount = Double(testQuantity) * pricePerUnit

                // Check minimum order amount requirement
                guard CalculationConstants.SecurityDenominations.meetsMinimumOrderAmount(
                    orderAmount,
                    minimumOrderAmount: nil // Don't apply minimum to investment portion individually
                ) else {
                    // Order amount too small, try next denomination multiple
                    testQuantity += denomination
                    continue
                }

                let fees = FeeCalculationService.calculateTotalFees(for: orderAmount)
                let totalCost = orderAmount + fees

                if totalCost <= investmentBalance {
                    // Can afford this quantity
                    bestQuantity = testQuantity
                    testQuantity += denomination // Try next denomination multiple
                } else {
                    // Too expensive, we've found the maximum
                    break
                }
            }

            print("   ✅ Final quantity (with denomination): \(bestQuantity)")
            return bestQuantity
        } else {
            // No denomination constraint - use standard binary search
            // Start from minimum required quantity
            var low = minRequiredQuantity
            var high = upperBound
            var bestQuantity = 0

            while low <= high {
                let mid = (low + high) / 2
                // Calculate order amount: units × price per unit
                let orderAmount = Double(mid) * pricePerUnit

                // Check minimum order amount requirement
                guard CalculationConstants.SecurityDenominations.meetsMinimumOrderAmount(
                    orderAmount,
                    minimumOrderAmount: nil // Don't apply minimum to investment portion individually
                ) else {
                    // Order amount too small, need more quantity
                    low = mid + 1
                    continue
                }

                let fees = FeeCalculationService.calculateTotalFees(for: orderAmount)
                let totalCost = orderAmount + fees

                if totalCost <= investmentBalance {
                    // Can afford this quantity
                    bestQuantity = mid
                    low = mid + 1 // Try more
                } else {
                    // Too expensive
                    high = mid - 1 // Try less
                }
            }

            print("   ✅ Final quantity (binary search): \(bestQuantity)")
            return bestQuantity
        }
    }

    /// Calculates the combined order details for trader + investment purchase
    /// Delegates to CombinedOrderCalculator for the actual calculation
    func calculateCombinedOrderDetails(
        traderQuantity: Int,
        traderCashBalance: Double,
        investmentBalance: Double,
        pricePerSecurity: Double,
        denomination: Int? = nil,
        subscriptionRatio: Double = 1.0,
        minimumOrderAmount: Double? = nil
    ) -> CombinedOrderCalculationResult {
        return combinedOrderCalculator.calculateCombinedOrderDetails(
            traderQuantity: traderQuantity,
            traderCashBalance: traderCashBalance,
            investmentBalance: investmentBalance,
            pricePerSecurity: pricePerSecurity,
            denomination: denomination,
            subscriptionRatio: subscriptionRatio,
            minimumOrderAmount: minimumOrderAmount
        )
    }

    // MARK: - ServiceLifecycle

    func start() {
        // Service is stateless, no initialization needed
    }

    func stop() {
        // Service is stateless, no cleanup needed
    }

    func reset() {
        // Service is stateless, no reset needed
    }
}
