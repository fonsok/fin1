import Foundation

@MainActor
extension InvestorCashBalanceService {
    func processInvestment(investorId: String, amount: Double, investmentId: String) async {
        await MainActor.run {
            let currentBalance = balances[investorId] ?? initialInvestorBalance
            let newBalance = max(0, currentBalance - amount)
            balances[investorId] = newBalance

            ledgerService.recordTransaction(
                investorId: investorId,
                title: "Investment Reserved",
                subtitle: "Investment \(investmentId)",
                amount: amount,
                direction: .debit,
                category: .investment,
                reference: investmentId,
                metadata: ["investmentId": investmentId, "transactionType": "investment"],
                balanceAfter: newBalance
            )

            NotificationCenter.default.post(
                name: .investorBalanceDidChange,
                object: nil,
                userInfo: [
                    "investorId": investorId,
                    "newBalance": newBalance,
                    "investmentId": investmentId,
                    "transactionType": "investment"
                ]
            )
        }
        let newBalance = getBalance(for: investorId)
        print(
            "💰 Investor \(investorId) - Investment [ID: \(investmentId)]: -€\(amount.formatted(.currency(code: "EUR"))) | New balance: €\(newBalance.formatted(.currency(code: "EUR")))"
        )
    }

    func processAppServiceCharge(
        investorId: String,
        chargeAmount: Double,
        investmentId: String,
        metadata additionalMetadata: [String: String] = [:]
    ) async {
        await MainActor.run {
            let currentBalance = balances[investorId] ?? initialInvestorBalance
            let newBalance = max(0, currentBalance - chargeAmount)
            balances[investorId] = newBalance

            var metadata: [String: String] = [
                "investmentId": investmentId,
                "transactionType": "appServiceCharge",
                "isRefundable": "false"
            ]
            additionalMetadata.forEach { metadata[$0.key] = $0.value }

            ledgerService.recordTransaction(
                investorId: investorId,
                title: "App Service Charge",
                subtitle: "Investment \(investmentId)",
                amount: chargeAmount,
                direction: .debit,
                category: .serviceCharge,
                reference: investmentId,
                metadata: metadata,
                balanceAfter: newBalance
            )

            var userInfo: [String: Any] = [
                "investorId": investorId,
                "newBalance": newBalance,
                "investmentId": investmentId,
                "transactionType": "appServiceCharge",
                "isRefundable": false
            ]
            additionalMetadata.forEach { userInfo[$0.key] = $0.value }
            NotificationCenter.default.post(name: .investorBalanceDidChange, object: nil, userInfo: userInfo)
        }
        let newBalance = getBalance(for: investorId)
        print(
            "💰 Investor \(investorId) - App Service Charge [Investment ID: \(investmentId), NON-REFUNDABLE]: -€\(chargeAmount.formatted(.currency(code: "EUR"))) | New balance: €\(newBalance.formatted(.currency(code: "EUR")))"
        )
    }

    func processPlatformServiceCharge(
        investorId: String,
        chargeAmount: Double,
        investmentId: String,
        metadata additionalMetadata: [String: String] = [:]
    ) async {
        await self.processAppServiceCharge(
            investorId: investorId,
            chargeAmount: chargeAmount,
            investmentId: investmentId,
            metadata: additionalMetadata
        )
    }

    func processProfitDistribution(investorId: String, profitAmount: Double, investmentId: String? = nil) async {
        await self.processProfitDistribution(
            investorId: investorId,
            profitAmount: profitAmount,
            investmentId: investmentId,
            principalReturn: nil,
            grossProfit: nil
        )
    }

    func processProfitDistributionWithBreakdown(
        investorId: String,
        profitAmount: Double,
        principalReturn: Double,
        grossProfit: Double,
        investmentId: String? = nil
    ) async {
        await self.processProfitDistribution(
            investorId: investorId,
            profitAmount: profitAmount,
            investmentId: investmentId,
            principalReturn: principalReturn,
            grossProfit: grossProfit
        )
    }

    func processCommissionDeduction(
        investorId: String,
        commissionAmount: Double,
        investmentId: String? = nil,
        details: CommissionDeductionDetails? = nil
    ) async {
        guard commissionAmount > 0 else {
            print("💰 InvestorCashBalanceService.processCommissionDeduction: Commission amount is 0 or negative, skipping")
            return
        }

        await MainActor.run {
            let currentBalance = balances[investorId] ?? initialInvestorBalance
            let newBalance = max(0, currentBalance - commissionAmount)
            balances[investorId] = newBalance

            var metadata: [String: String] = ["transactionType": "commissionDeduction"]
            if let investmentId = investmentId { metadata["investmentId"] = investmentId }
            if let details = details {
                if let seqNum = details.investmentSequenceNumber { metadata["investmentSequenceNumber"] = String(seqNum) }
                if let traderName = details.traderName, !traderName.isEmpty { metadata["traderName"] = traderName }
                if !details.tradeNumbers.isEmpty { metadata["tradeNumbers"] = details.tradeNumbers.joined(separator: ", ") }
                metadata["grossProfit"] = String(format: "%.2f", details.grossProfit)
                metadata["commissionRate"] = String(format: "%.0f", details.commissionRate * 100)
            }

            var subtitleParts: [String] = []
            if let details = details, let seqNum = details.investmentSequenceNumber {
                subtitleParts.append("Investment #\(seqNum)")
            } else if let investmentId = investmentId {
                subtitleParts.append("Investment \(investmentId)")
            }
            if let details = details, !details.tradeNumbers.isEmpty {
                subtitleParts.append("Trade \(details.tradeNumbers.joined(separator: ", "))")
            }
            let subtitle = subtitleParts.isEmpty ? nil : subtitleParts.joined(separator: " · ")

            ledgerService.recordTransaction(
                investorId: investorId,
                title: "Commission",
                subtitle: subtitle,
                amount: commissionAmount,
                direction: .debit,
                category: .commission,
                reference: investmentId,
                metadata: metadata,
                balanceAfter: newBalance
            )
            NotificationCenter.default.post(
                name: .investorBalanceDidChange,
                object: nil,
                userInfo: ["investorId": investorId, "newBalance": newBalance]
            )
        }
        let newBalance = getBalance(for: investorId)
        let investmentInfo = investmentId.map { " [Investment ID: \($0)]" } ?? ""
        print(
            "💰 Investor \(investorId) - Commission deduction\(investmentInfo): -€\(commissionAmount.formatted(.currency(code: "EUR"))) | New balance: €\(newBalance.formatted(.currency(code: "EUR")))"
        )
    }

    func processCommissionDeduction(investorId: String, commissionAmount: Double, investmentId: String? = nil) async {
        await self.processCommissionDeduction(
            investorId: investorId,
            commissionAmount: commissionAmount,
            investmentId: investmentId,
            details: nil
        )
    }

    func processRemainingBalanceDistribution(investorId: String, amount: Double, investmentId: String? = nil) async {
        await MainActor.run {
            let currentBalance = balances[investorId] ?? initialInvestorBalance
            let newBalance = currentBalance + amount
            balances[investorId] = newBalance

            var metadata: [String: String] = ["transactionType": "remainingBalanceDistribution"]
            if let investmentId = investmentId { metadata["investmentId"] = investmentId }
            ledgerService.recordTransaction(
                investorId: investorId,
                title: "Balance Distribution",
                amount: amount,
                direction: .credit,
                category: .remainingBalance,
                metadata: metadata,
                balanceAfter: newBalance
            )
            NotificationCenter.default.post(
                name: .investorBalanceDidChange,
                object: nil,
                userInfo: ["investorId": investorId, "newBalance": newBalance]
            )
        }
        let newBalance = getBalance(for: investorId)
        let investmentInfo = investmentId.map { " [Investment ID: \($0)]" } ?? ""
        print(
            "💰 Investor \(investorId) - Remaining balance distribution\(investmentInfo): +€\(amount.formatted(.currency(code: "EUR"))) | New balance: €\(newBalance.formatted(.currency(code: "EUR")))"
        )
    }

    func hasSufficientFunds(investorId: String, for amount: Double) -> Bool {
        getBalance(for: investorId) >= amount
    }

    func estimatedBalanceAfterInvestment(investorId: String, amount: Double) -> Double {
        max(0, getBalance(for: investorId) - amount)
    }

    func resetBalance(for investorId: String) async {
        await MainActor.run {
            balances[investorId] = initialInvestorBalance
        }
        ledgerService.clearTransactions(for: investorId)
        print("💰 Investor \(investorId) - Balance reset to initial: €\(initialInvestorBalance.formatted(.currency(code: "EUR")))")
    }

    func processDeposit(investorId: String, amount: Double) async {
        await MainActor.run {
            let currentBalance = balances[investorId] ?? initialInvestorBalance
            let newBalance = currentBalance + amount
            balances[investorId] = newBalance
            NotificationCenter.default.post(
                name: .investorBalanceDidChange,
                object: nil,
                userInfo: ["investorId": investorId, "newBalance": newBalance]
            )
        }
        let newBalance = getBalance(for: investorId)
        print(
            "💰 Investor \(investorId) - Deposit: +€\(amount.formatted(.currency(code: "EUR"))) | New balance: €\(newBalance.formatted(.currency(code: "EUR")))"
        )
    }

    func processWithdrawal(investorId: String, amount: Double) async {
        await MainActor.run {
            let currentBalance = balances[investorId] ?? initialInvestorBalance
            let newBalance = max(0, currentBalance - amount)
            balances[investorId] = newBalance
            NotificationCenter.default.post(
                name: .investorBalanceDidChange,
                object: nil,
                userInfo: ["investorId": investorId, "newBalance": newBalance]
            )
        }
        let newBalance = getBalance(for: investorId)
        print(
            "💰 Investor \(investorId) - Withdrawal: -€\(amount.formatted(.currency(code: "EUR"))) | New balance: €\(newBalance.formatted(.currency(code: "EUR")))"
        )
    }

    private func processProfitDistribution(
        investorId: String,
        profitAmount: Double,
        investmentId: String?,
        principalReturn: Double?,
        grossProfit: Double?
    ) async {
        await MainActor.run {
            let currentBalance = balances[investorId] ?? initialInvestorBalance
            let newBalance = currentBalance + profitAmount
            balances[investorId] = newBalance

            var metadata: [String: String] = ["transactionType": "profitDistribution"]
            if let investmentId = investmentId { metadata["investmentId"] = investmentId }
            if let principalReturn = principalReturn { metadata["principalReturn"] = String(format: "%.2f", principalReturn) }
            if let grossProfit = grossProfit { metadata["grossProfit"] = String(format: "%.2f", grossProfit) }

            ledgerService.recordTransaction(
                investorId: investorId,
                title: "Profit Distribution",
                amount: profitAmount,
                direction: .credit,
                category: .profitDistribution,
                metadata: metadata,
                balanceAfter: newBalance
            )
            NotificationCenter.default.post(
                name: .investorBalanceDidChange,
                object: nil,
                userInfo: ["investorId": investorId, "newBalance": newBalance]
            )
        }
        let newBalance = getBalance(for: investorId)
        let investmentInfo = investmentId.map { " [Investment ID: \($0)]" } ?? ""
        print(
            "💰 Investor \(investorId) - Profit distribution\(investmentInfo): +€\(profitAmount.formatted(.currency(code: "EUR"))) | New balance: €\(newBalance.formatted(.currency(code: "EUR")))"
        )
    }
}
