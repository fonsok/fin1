import Foundation

extension CompletedInvestmentDetailViewModel {
    var investedAmount: Double { self.investment.amount }
    var investedAmountText: String { self.investedAmount.formattedAsLocalizedCurrency() }

    var currentValue: Double {
        if let statementSummary {
            return self.investedAmount + statementSummary.statementGrossProfit
        }
        if let canonical = canonicalSummary {
            return self.investedAmount + canonical.grossProfit
        }
        guard !self.monetaryServerOnly else { return self.investedAmount }
        return self.investment.currentValue
    }

    var currentValueText: String { self.currentValue.formattedAsLocalizedCurrency() }

    var profit: Double {
        if let statementSummary { return statementSummary.statementGrossProfit }
        if let canonical = canonicalSummary { return canonical.grossProfit }
        guard !self.monetaryServerOnly else { return 0 }
        return self.currentValue - self.investedAmount
    }

    var profitText: String { self.profit.formattedAsLocalizedCurrency() }
    var isProfitPositive: Bool { self.profit >= 0 }

    var returnPercentage: Double { self.tradeLedReturnPercentageValue ?? 0.0 }

    var returnPercentageText: String {
        guard let tradeLedReturnPercentageValue else { return "pending" }
        return NumberFormatter.localizedDecimalFormatter.string(for: tradeLedReturnPercentageValue).map { "\($0) %" } ?? "0,00 %"
    }

    var provisionAmount: Double {
        guard let configurationService else { return 0.0 }
        return self.investedAmount * configurationService.effectiveAppServiceChargeRate
    }

    var provisionAmountText: String { self.provisionAmount.formattedAsLocalizedCurrency() }

    var commissionAmount: Double {
        guard self.profit > 0, let configurationService else { return 0.0 }
        let commissionRate = configurationService.effectiveInvestorCommissionRate
        return self.commissionCalculationService?.calculateCommission(
            grossProfit: self.profit,
            rate: commissionRate
        ) ?? 0.0
    }

    var commissionAmountText: String { self.commissionAmount.formattedAsLocalizedCurrency() }

    var capitalGainsTaxAmount: Double {
        InvoiceTaxCalculator.calculateCapitalGainsTax(for: max(self.profit, 0))
    }

    var solidaritySurchargeAmount: Double {
        InvoiceTaxCalculator.calculateSolidaritySurcharge(for: self.capitalGainsTaxAmount)
    }

    var churchTaxAmount: Double {
        InvoiceTaxCalculator.calculateChurchTax(for: self.capitalGainsTaxAmount)
    }

    var totalTaxAmount: Double {
        self.capitalGainsTaxAmount + self.solidaritySurchargeAmount + self.churchTaxAmount
    }

    var capitalGainsTaxText: String { self.capitalGainsTaxAmount.formattedAsLocalizedCurrency() }
    var solidaritySurchargeText: String { self.solidaritySurchargeAmount.formattedAsLocalizedCurrency() }
    var churchTaxText: String { self.churchTaxAmount.formattedAsLocalizedCurrency() }
    var totalTaxText: String { self.totalTaxAmount.formattedAsLocalizedCurrency() }

    var netProfitAfterCharges: Double {
        self.profit - self.totalTaxAmount - self.provisionAmount
    }

    var netProfitAfterChargesText: String { self.netProfitAfterCharges.formattedAsLocalizedCurrency() }
    var hasPositiveNetProfit: Bool { self.netProfitAfterCharges >= 0 }
}
