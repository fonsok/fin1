import Foundation

extension BuyOrderViewModel {

    func updateInsufficientFundsWarning() {
        guard let currentUser = userService.currentUser else {
            showInsufficientFundsWarning = false
            return
        }
        let minimumReserve = configurationService.getMinimumCashReserve(for: currentUser.id)
        let hasSufficientFunds = cashBalanceService.hasSufficientFunds(for: estimatedCost, minimumReserve: minimumReserve)
        showInsufficientFundsWarning = !hasSufficientFunds
    }

    @MainActor
    func checkTransactionLimits() async {
        guard let limitService = transactionLimitService,
              let userId = userService.currentUser?.id,
              estimatedCost > 0 else {
            transactionLimitCheckResult = nil
            showLimitWarning = false
            limitWarningMessage = nil
            remainingDailyLimit = nil
            return
        }

        do {
            let checkResult = try await limitService.checkAllLimits(userId: userId, amount: estimatedCost)
            transactionLimitCheckResult = checkResult
            remainingDailyLimit = checkResult.remainingDaily

            if !checkResult.isAllowed {
                showLimitWarning = true
                limitWarningMessage = checkResult.errorMessage
            } else {
                showLimitWarning = false
                limitWarningMessage = nil
            }
        } catch {
            print("⚠️ Transaction limit check failed: \(error.localizedDescription)")
            transactionLimitCheckResult = nil
            showLimitWarning = false
            limitWarningMessage = nil
        }
    }
}
