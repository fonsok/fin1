import Foundation

// MARK: - Buy Order Investment Calculator Protocol
@MainActor
protocol BuyOrderInvestmentCalculatorProtocol {
    func calculateInvestmentOrder(
        quantity: Int,
        price: Double,
        searchResult: SearchResult,
        userService: any UserServiceProtocol,
        investmentService: any InvestmentServiceProtocol,
        cashBalanceService: any CashBalanceServiceProtocol,
        investmentQuantityCalculationService: any InvestmentQuantityCalculationServiceProtocol
    ) async -> InvestmentCalculationResult?
}

// MARK: - Investment Calculation Result
struct InvestmentCalculationResult {
    let calculation: CombinedOrderCalculationResult
    let isInvestmentLimited: Bool
    let showInvestmentCalculation: Bool
    let isTraderLimited: Bool
    let traderQuantity: Int
}

// MARK: - Buy Order Investment Calculator
/// Handles investment calculation coordination for buy orders
@MainActor
final class BuyOrderInvestmentCalculator: BuyOrderInvestmentCalculatorProtocol {

    func calculateInvestmentOrder(
        quantity: Int,
        price: Double,
        searchResult: SearchResult,
        userService: any UserServiceProtocol,
        investmentService: any InvestmentServiceProtocol,
        cashBalanceService: any CashBalanceServiceProtocol,
        investmentQuantityCalculationService: any InvestmentQuantityCalculationServiceProtocol
    ) async -> InvestmentCalculationResult? {
        // Get current trader ID
        guard let currentUser = userService.currentUser else {
            // No user logged in - trader can place order normally
            return nil
        }

        let traderId = currentUser.id

        // CRITICAL FIX: Calculate investment balance from sum of all available investments
        // This ensures the order quantity calculation uses the same capital that will actually be used
        // in recordPoolParticipations, which sums activated investments' capital amounts.
        // Using activeInvestmentPool.currentBalance was incorrect because:
        // 1. It's a static value that doesn't reflect actual available capital
        // 2. It may not match the sum of individual investment amounts
        // 3. It can lead to underutilization of pool capital
        // Include investments that are reserved OR active (executing/closed are also participating)
        let allReservedInvestments = investmentService.getInvestments(forTrader: traderId)
            .filter { investment in
                investment.status == .active &&
                (investment.reservationStatus == .reserved ||
                 investment.reservationStatus == .active ||
                 investment.reservationStatus == .executing ||
                 investment.reservationStatus == .closed)
            }

        // Calculate total available capital from all reserved investments
        let investmentBalance = allReservedInvestments.reduce(0.0) { $0 + $1.amount }

        guard investmentBalance > 0 else {
            // No available investments with capital - trader can place order normally
            return nil
        }

        print("💰 BuyOrderInvestmentCalculator: Calculating order with full pool capital")
        print("   📊 Available investments count: \(allReservedInvestments.count)")
        print("   💵 Total pool capital (sum of available investments): €\(String(format: "%.2f", investmentBalance))")

        let traderCashBalance = cashBalanceService.currentBalance

        print("💰 BuyOrderInvestmentCalculator.calculateInvestmentOrder:")
        print("   📊 Input quantity (desired trader quantity): \(quantity)")
        print("   💵 traderCashBalance: €\(String(format: "%.2f", traderCashBalance))")
        print("   💵 investmentBalance (sum of reserved investments): €\(String(format: "%.2f", investmentBalance))")
        print("   📊 Reserved investments count: \(allReservedInvestments.count)")

        // Get security metadata
        let denomination = searchResult.denomination
        let subscriptionRatio = searchResult.subscriptionRatio
        let minimumOrderAmount = searchResult.minimumOrderAmount

        // Calculate combined order details
        let calculation = investmentQuantityCalculationService.calculateCombinedOrderDetails(
            traderQuantity: quantity,
            traderCashBalance: traderCashBalance,
            investmentBalance: investmentBalance,
            pricePerSecurity: price,
            denomination: denomination,
            subscriptionRatio: subscriptionRatio,
            minimumOrderAmount: minimumOrderAmount
        )

        return InvestmentCalculationResult(
            calculation: calculation,
            isInvestmentLimited: calculation.isInvestmentLimited,
            showInvestmentCalculation: calculation.investmentQuantity > 0,
            isTraderLimited: calculation.isTraderLimited,
            traderQuantity: calculation.traderQuantity
        )
    }
}
