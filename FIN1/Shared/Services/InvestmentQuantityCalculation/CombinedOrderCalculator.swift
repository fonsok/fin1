import Foundation

// MARK: - Combined Order Calculator

/// Handles combined order calculation logic for InvestmentQuantityCalculationService
/// Separated to reduce main service file size and improve maintainability
final class CombinedOrderCalculator {
    private let maxQuantityCalculator: (Double, Double, Int?, Double, Double?) -> Int

    init(maxQuantityCalculator: @escaping (Double, Double, Int?, Double, Double?) -> Int) {
        self.maxQuantityCalculator = maxQuantityCalculator
    }

    /// Calculates the combined order details for trader + investment purchase
    ///
    /// **CAPITAL MAXIMIZATION STRATEGY:**
    /// - Maximizes capital utilization by using ALL available trader cash balance and pool capital
    /// - The trader's input quantity (traderQuantity parameter) is COMPLETELY IGNORED
    /// - System calculates: max trader quantity from trader cash + max investment quantity from pool capital
    /// - Total order quantity = max trader quantity + max investment quantity
    ///
    /// The total executed quantity = max trader quantity + max investment quantity
    func calculateCombinedOrderDetails(
        traderQuantity: Int,
        traderCashBalance: Double,
        investmentBalance: Double,
        pricePerSecurity: Double,
        denomination: Int? = nil,
        subscriptionRatio: Double = 1.0,
        minimumOrderAmount: Double? = nil
    ) -> CombinedOrderCalculationResult {
        // Validate subscription ratio
        guard subscriptionRatio > 0 else {
            // Invalid subscription ratio, return zero result
            return CombinedOrderCalculationResult(
                traderQuantity: 0,
                investmentQuantity: 0,
                totalQuantity: 0,
                traderOrderAmount: 0,
                investmentOrderAmount: 0,
                totalOrderAmount: 0,
                totalFees: 0,
                traderFees: 0,
                investmentFees: 0,
                traderTotalCost: 0,
                investmentTotalCost: 0,
                totalCost: 0,
                traderRemainingBalance: traderCashBalance,
                investmentRemainingBalance: investmentBalance,
                isTraderLimited: true,
                isInvestmentLimited: true,
                feeBreakdown: [],
                investmentResidualAmount: investmentBalance,
                totalShares: 0,
                traderShares: 0,
                investmentShares: 0
            )
        }

        // Calculate price per unit (pricePerSecurity is per share)
        let pricePerUnit = pricePerSecurity / Double(subscriptionRatio)

        // MAXIMIZE CAPITAL UTILIZATION:
        // 1. Calculate maximum trader quantity from trader's cash balance (ignore traderQuantity input)
        //    This ensures we use all available trader capital, similar to a mirror trade
        print("💰 CombinedOrderCalculator.calculateCombinedOrderDetails:")
        print("   📊 traderQuantity (INPUT - IGNORED): \(traderQuantity)")
        print("   💵 traderCashBalance: €\(String(format: "%.2f", traderCashBalance))")
        print("   💵 investmentBalance (pool capital): €\(String(format: "%.2f", investmentBalance))")
        print("   💵 pricePerSecurity: €\(String(format: "%.2f", pricePerSecurity))")
        print("   📐 denomination: \(denomination?.description ?? "nil")")
        print("   📐 subscriptionRatio: \(subscriptionRatio)")

        let actualTraderQuantity = maxQuantityCalculator(
            traderCashBalance,
            pricePerSecurity,
            denomination,
            subscriptionRatio,
            nil // Don't apply minimum to trader portion individually
        )
        print("   ✅ actualTraderQuantity (MAXIMIZED from cash): \(actualTraderQuantity)")

        // Trader is limited only if they have no cash balance or cannot purchase any quantity
        let isTraderLimited = actualTraderQuantity == 0 && traderCashBalance > 0

        // 2. Calculate maximum investment quantity from pool capital
        //    This ensures we use all available pool capital, maximizing capital utilization
        let investmentQuantity = maxQuantityCalculator(
            investmentBalance,
            pricePerSecurity,
            denomination,
            subscriptionRatio,
            nil // Don't apply minimum to investment portion individually
        )
        print("   ✅ investmentQuantity (MAXIMIZED from pool): \(investmentQuantity)")

        // 3. Calculate total order (trader + investment) in units
        let totalQuantity = actualTraderQuantity + investmentQuantity
        print("   ✅ totalQuantity (trader + investment): \(totalQuantity)")
        print("   📊 Calculation complete: Trader=\(actualTraderQuantity) + Pool=\(investmentQuantity) = Total=\(totalQuantity)")
        // CRITICAL FIX: totalOrderAmount should be securities value (quantity × pricePerSecurity)
        // NOT quantity × pricePerUnit, because pricePerUnit is for quantity calculations only
        let totalOrderAmount = Double(totalQuantity) * pricePerSecurity

        // 4. Validate minimum order amount for total order
        // Note: Individual portions (trader/investment) may be below minimum, but total must meet it
        if let minimum = minimumOrderAmount, minimum > 0 {
            guard totalOrderAmount >= minimum else {
                // Total order doesn't meet minimum - return zero quantities
                return CombinedOrderCalculationResult(
                    traderQuantity: 0,
                    investmentQuantity: 0,
                    totalQuantity: 0,
                    traderOrderAmount: 0,
                    investmentOrderAmount: 0,
                    totalOrderAmount: 0,
                    totalFees: 0,
                    traderFees: 0,
                    investmentFees: 0,
                    traderTotalCost: 0,
                    investmentTotalCost: 0,
                    totalCost: 0,
                    traderRemainingBalance: traderCashBalance,
                    investmentRemainingBalance: investmentBalance,
                    isTraderLimited: true,
                    isInvestmentLimited: true,
                    feeBreakdown: [],
                    investmentResidualAmount: investmentBalance,
                    totalShares: 0,
                    traderShares: 0,
                    investmentShares: 0
                )
            }
        }

        // 5. Calculate total fees for the combined order
        let totalFees = FeeCalculationService.calculateTotalFees(for: totalOrderAmount)

        // 6. Split fees proportionally between trader and investment
        // CRITICAL FIX: Order amounts should be securities value (quantity × pricePerSecurity)
        let traderOrderAmountActual = Double(actualTraderQuantity) * pricePerSecurity
        let investmentOrderAmount = Double(investmentQuantity) * pricePerSecurity

        let traderFees: Double
        let investmentFees: Double

        if totalOrderAmount > 0 {
            let traderProportion = traderOrderAmountActual / totalOrderAmount
            let investmentProportion = investmentOrderAmount / totalOrderAmount
            traderFees = totalFees * traderProportion
            investmentFees = totalFees * investmentProportion
        } else {
            traderFees = 0
            investmentFees = 0
        }

        // 7. Calculate total costs
        let traderTotalCost = traderOrderAmountActual + traderFees
        let investmentTotalCost = investmentOrderAmount + investmentFees
        let totalCost = traderTotalCost + investmentTotalCost

        // 8. Calculate remaining balances
        let traderRemainingBalance = traderCashBalance - traderTotalCost
        let investmentRemainingBalance = investmentBalance - investmentTotalCost

        // 9. Calculate residual amount (leftover investment funds that can't buy a full denomination)
        // Residual is the amount that remains after purchasing the maximum possible quantity
        let investmentResidualAmount: Double
        if investmentQuantity > 0 {
            // If we purchased something, residual is the remaining balance
            // But if there's a denomination constraint, check if we can buy more
            if let denomination = denomination {
                // Check if remaining balance can buy at least one more denomination unit
                let nextDenominationCost = Double(denomination) * pricePerUnit
                let feesForNext = FeeCalculationService.calculateTotalFees(for: nextDenominationCost)
                let totalCostForNext = nextDenominationCost + feesForNext

                if investmentRemainingBalance >= totalCostForNext {
                    // Can still buy more, so no residual (this shouldn't happen if calculation is correct)
                    investmentResidualAmount = 0
                } else {
                    // Cannot buy more, remaining balance is residual
                    investmentResidualAmount = max(0, investmentRemainingBalance)
                }
            } else {
                // No denomination constraint, check if we can buy at least 1 more unit
                let oneUnitCost = pricePerUnit
                let feesForOne = FeeCalculationService.calculateTotalFees(for: oneUnitCost)
                let totalCostForOne = oneUnitCost + feesForOne

                if investmentRemainingBalance >= totalCostForOne {
                    // Can still buy more, so no residual (this shouldn't happen if calculation is correct)
                    investmentResidualAmount = 0
                } else {
                    // Cannot buy more, remaining balance is residual
                    investmentResidualAmount = max(0, investmentRemainingBalance)
                }
            }
        } else {
            // No investment quantity purchased, all balance is residual
            investmentResidualAmount = investmentBalance
        }

        // 10. Check if investment is limited (always false if investmentQuantity > 0, since we calculate max)
        let isInvestmentLimited = investmentQuantity == 0 && investmentBalance > 0

        // 11. Calculate shares from units using subscription ratio
        let traderShares = Int(Double(actualTraderQuantity) / subscriptionRatio)
        let investmentShares = Int(Double(investmentQuantity) / subscriptionRatio)
        let totalShares = traderShares + investmentShares

        // 12. Get fee breakdown
        let feeBreakdown = FeeCalculationService.createFeeBreakdown(for: totalOrderAmount)

        return CombinedOrderCalculationResult(
            traderQuantity: actualTraderQuantity,
            investmentQuantity: investmentQuantity,
            totalQuantity: totalQuantity,
            traderOrderAmount: traderOrderAmountActual,
            investmentOrderAmount: investmentOrderAmount,
            totalOrderAmount: totalOrderAmount,
            totalFees: totalFees,
            traderFees: traderFees,
            investmentFees: investmentFees,
            traderTotalCost: traderTotalCost,
            investmentTotalCost: investmentTotalCost,
            totalCost: totalCost,
            traderRemainingBalance: max(0, traderRemainingBalance),
            investmentRemainingBalance: max(0, investmentRemainingBalance),
            isTraderLimited: isTraderLimited,
            isInvestmentLimited: isInvestmentLimited,
            feeBreakdown: feeBreakdown,
            investmentResidualAmount: investmentResidualAmount,
            totalShares: totalShares,
            traderShares: traderShares,
            investmentShares: investmentShares
        )
    }
}







