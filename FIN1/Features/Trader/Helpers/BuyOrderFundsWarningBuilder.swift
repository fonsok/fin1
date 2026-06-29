import Foundation

@MainActor
enum BuyOrderFundsWarningBuilder {

    static func shouldShowInsufficientFundsWarning(
        userService: any UserServiceProtocol,
        cashBalanceService: any CashBalanceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        estimatedCost: Double
    ) -> Bool {
        guard let userId = userService.currentUser?.id else { return false }
        let minimumReserve = configurationService.getMinimumCashReserve(for: userId)
        return !cashBalanceService.hasSufficientFunds(for: estimatedCost, minimumReserve: minimumReserve)
    }

    static func insufficientFundsMessage(
        userService: any UserServiceProtocol,
        cashBalanceService: any CashBalanceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        estimatedCost: Double
    ) -> String {
        guard let userId = userService.currentUser?.id else {
            return "Please log in to check your balance."
        }
        let currentBalance = cashBalanceService.currentBalance
        let estimatedBalance = cashBalanceService.estimatedBalanceAfterPurchase(amount: estimatedCost)
        let minimumReserve = configurationService.getMinimumCashReserve(for: userId)
        let shortfall = minimumReserve - estimatedBalance
        return "Insufficient funds. Current balance: €\(currentBalance.formatted(.currency(code: "EUR"))), Estimated after purchase: €\(estimatedBalance.formatted(.currency(code: "EUR"))). Need €\(shortfall.formatted(.currency(code: "EUR"))) more to maintain minimum reserve of €\(minimumReserve.formatted(.currency(code: "EUR")))."
    }
}
