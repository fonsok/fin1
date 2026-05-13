import Foundation

// MARK: - Securities Value Calculator
/// Pure calculation service for computing maximum securities value from available capital
/// Accounts for fees and denomination constraints
struct SecuritiesValueCalculator {

    // MARK: - Public API

    /// Calculates the maximum securities value that can be purchased with the given capital
    /// Accounts for fees using binary search to find the optimal quantity
    /// - Parameters:
    ///   - totalCapital: Total pool capital available
    ///   - pricePerSecurity: Price per security (share) in EUR
    ///   - subscriptionRatio: Subscription ratio (units per share)
    ///   - denomination: Optional denomination constraint
    ///   - verbose: Whether to print debug logs (default: true)
    /// - Returns: Maximum securities value (price × quantity) that can be purchased
    static func calculateMaxSecuritiesValue(
        fromCapital totalCapital: Double,
        pricePerSecurity: Double,
        subscriptionRatio: Double,
        denomination: Int?,
        verbose: Bool = true
    ) -> Double {
        if verbose {
            print("🔍 SecuritiesValueCalculator: Starting calculation")
            print("   💵 Total capital: €\(String(format: "%.2f", totalCapital))")
            print("   💰 Price per security: €\(String(format: "%.2f", pricePerSecurity))")
            print("   📊 Subscription ratio: \(subscriptionRatio)")
            print("   🔢 Denomination: \(denomination?.description ?? "nil")")
        }

        guard totalCapital > 0, pricePerSecurity > 0, subscriptionRatio > 0 else {
            if verbose { print("   ❌ Invalid inputs - returning 0.0") }
            return 0.0
        }

        let pricePerUnit = pricePerSecurity / subscriptionRatio
        if verbose { print("   💵 Price per unit: €\(String(format: "%.2f", pricePerUnit))") }

        let maxPossibleQuantity = Int(totalCapital / pricePerUnit)
        if verbose { print("   📦 Max possible quantity (no fees): \(maxPossibleQuantity)") }

        guard maxPossibleQuantity > 0 else {
            if verbose { print("   ❌ Max possible quantity is 0 - returning 0.0") }
            return 0.0
        }

        let upperBound = self.calculateUpperBound(
            maxPossibleQuantity: maxPossibleQuantity,
            denomination: denomination,
            verbose: verbose
        )

        guard upperBound > 0 else {
            if verbose { print("   ❌ Upper bound is 0 - returning 0.0") }
            return 0.0
        }

        let bestQuantity = self.findOptimalQuantity(
            upperBound: upperBound,
            pricePerUnit: pricePerUnit,
            totalCapital: totalCapital,
            denomination: denomination,
            verbose: verbose
        )

        let securitiesValue = Double(bestQuantity) * pricePerUnit
        if verbose {
            let remainingCapital = totalCapital - (securitiesValue + FeeCalculationService.calculateTotalFees(for: securitiesValue))
            print("   ✅ Final result:")
            print("      📦 Best quantity: \(bestQuantity) units")
            print("      💵 Securities value: €\(String(format: "%.2f", securitiesValue))")
            print("      💵 Remaining capital: €\(String(format: "%.2f", remainingCapital))")
            print(
                "      📊 Capital utilization: \(totalCapital > 0 ? String(format: "%.2f", ((totalCapital - remainingCapital) / totalCapital) * 100) : "0")%"
            )
        }

        return securitiesValue
    }

    // MARK: - Private Helpers

    private static func calculateUpperBound(
        maxPossibleQuantity: Int,
        denomination: Int?,
        verbose: Bool
    ) -> Int {
        if let denomination = denomination {
            let bound = CalculationConstants.SecurityDenominations.roundDownToDenomination(
                maxPossibleQuantity,
                denominations: [denomination]
            )
            if verbose { print("   🔢 Upper bound (with denomination): \(bound)") }
            return bound
        } else {
            if verbose { print("   🔢 Upper bound (no denomination): \(maxPossibleQuantity)") }
            return maxPossibleQuantity
        }
    }

    private static func findOptimalQuantity(
        upperBound: Int,
        pricePerUnit: Double,
        totalCapital: Double,
        denomination: Int?,
        verbose: Bool
    ) -> Int {
        var bestQuantity = 0

        if let denomination = denomination {
            if verbose { print("   🔍 Searching with denomination constraint: \(denomination)") }
            bestQuantity = self.searchWithDenomination(
                upperBound: upperBound,
                denomination: denomination,
                pricePerUnit: pricePerUnit,
                totalCapital: totalCapital,
                verbose: verbose
            )
        } else {
            if verbose { print("   🔍 Using binary search (no denomination)") }
            bestQuantity = self.binarySearch(
                upperBound: upperBound,
                pricePerUnit: pricePerUnit,
                totalCapital: totalCapital,
                verbose: verbose
            )
        }

        return bestQuantity
    }

    private static func searchWithDenomination(
        upperBound: Int,
        denomination: Int,
        pricePerUnit: Double,
        totalCapital: Double,
        verbose: Bool
    ) -> Int {
        var bestQuantity = 0
        var testQuantity = denomination

        while testQuantity <= upperBound {
            let orderAmount = Double(testQuantity) * pricePerUnit
            let fees = FeeCalculationService.calculateTotalFees(for: orderAmount)
            let totalCost = orderAmount + fees

            if verbose {
                print(
                    "      Testing quantity \(testQuantity): orderAmount=€\(String(format: "%.2f", orderAmount)), fees=€\(String(format: "%.2f", fees)), totalCost=€\(String(format: "%.2f", totalCost)), capital=€\(String(format: "%.2f", totalCapital))"
                )
            }

            if totalCost <= totalCapital {
                bestQuantity = testQuantity
                if verbose { print("      ✅ Can afford \(testQuantity) units") }
                testQuantity += denomination
            } else {
                if verbose { print("      ❌ Cannot afford \(testQuantity) units - stopping") }
                break
            }
        }

        return bestQuantity
    }

    private static func binarySearch(
        upperBound: Int,
        pricePerUnit: Double,
        totalCapital: Double,
        verbose: Bool
    ) -> Int {
        var bestQuantity = 0
        var low = 0
        var high = upperBound

        while low <= high {
            let mid = (low + high) / 2
            let orderAmount = Double(mid) * pricePerUnit
            let fees = FeeCalculationService.calculateTotalFees(for: orderAmount)
            let totalCost = orderAmount + fees

            if totalCost <= totalCapital {
                bestQuantity = mid
                if verbose {
                    print(
                        "      ✅ Can afford \(mid) units (orderAmount=€\(String(format: "%.2f", orderAmount)), fees=€\(String(format: "%.2f", fees)), totalCost=€\(String(format: "%.2f", totalCost)))"
                    )
                }
                low = mid + 1
            } else {
                if verbose {
                    print(
                        "      ❌ Cannot afford \(mid) units (totalCost=€\(String(format: "%.2f", totalCost)) > capital=€\(String(format: "%.2f", totalCapital)))"
                    )
                }
                high = mid - 1
            }
        }

        return bestQuantity
    }
}











