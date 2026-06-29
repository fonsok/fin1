import Foundation

extension BuyOrderViewModel {

    func updateInsufficientFundsWarning() {
        showInsufficientFundsWarning = BuyOrderFundsWarningBuilder.shouldShowInsufficientFundsWarning(
            userService: userService,
            cashBalanceService: cashBalanceService,
            configurationService: configurationService,
            estimatedCost: estimatedCost
        )
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
            #if DEBUG
            print("⚠️ Transaction limit check failed: \(error.localizedDescription)")
            #endif
            transactionLimitCheckResult = nil
            showLimitWarning = false
            limitWarningMessage = nil
        }
    }
}
