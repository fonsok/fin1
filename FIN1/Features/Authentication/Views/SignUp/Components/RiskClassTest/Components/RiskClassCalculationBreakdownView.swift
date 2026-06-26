import SwiftUI

struct RiskClassCalculationBreakdownView: View {
    let signUpData: SignUpData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Calculation Breakdown")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
            
            VStack(alignment: .leading, spacing: 12) {
                BreakdownRow(
                    title: "Income Range",
                    value: self.signUpData.incomeRange?.displayName ?? SignUpStepSelectionPrompt.pleaseSelect,
                    points: self.getIncomePoints()
                )
                BreakdownRow(
                    title: "Cash & Assets",
                    value: self.signUpData.cashAndLiquidAssets?.displayName ?? SignUpStepSelectionPrompt.pleaseSelect,
                    points: self.getAssetsPoints()
                )
                BreakdownRow(title: "Income Sources", value: self.getIncomeSourcesText(), points: self.getIncomeSourcesPoints())
                BreakdownRow(
                    title: "Stocks Experience",
                    value: self.signUpData.stocksTransactionsCount?.displayName ?? SignUpStepSelectionPrompt.pleaseSelect,
                    points: self.getStocksPoints()
                )
                BreakdownRow(
                    title: "ETFs Experience",
                    value: self.signUpData.etfsTransactionsCount?.displayName ?? SignUpStepSelectionPrompt.pleaseSelect,
                    points: self.getETFsPoints()
                )
                BreakdownRow(
                    title: "Derivatives Experience",
                    value: self.signUpData.derivativesTransactionsCount?.displayName ?? SignUpStepSelectionPrompt.pleaseSelect,
                    points: self.getDerivativesPoints()
                )
                BreakdownRow(title: "Investment Amounts", value: self.getInvestmentAmountsText(), points: self.getInvestmentAmountsPoints())
                BreakdownRow(
                    title: "Derivatives Holding",
                    value: self.signUpData.derivativesHoldingPeriod?.displayName ?? SignUpStepSelectionPrompt.pleaseSelect,
                    points: self.getHoldingPeriodPoints()
                )
                BreakdownRow(title: "Desired Return", value: self.signUpData.desiredReturn.displayName, points: self.getReturnPoints())
                BreakdownRow(title: "Other Assets", value: self.getOtherAssetsText(), points: self.getOtherAssetsPoints())
                
                Divider()
                
                HStack {
                    Text("TOTAL SCORE")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)
                    
                    Spacer()
                    
                    Text("\(self.getTotalScore()) points")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.accentOrange)
                }
            }
        }
        .signUpListSection(stripeIndex: 0)
    }
    
    private func getIncomePoints() -> Int {
        guard let incomeRange = self.signUpData.incomeRange else { return 0 }
        switch incomeRange {
        case .low: return 0
        case .lowMiddle: return 1
        case .middle: return 2
        case .highMiddle: return 3
        case .high: return 4
        case .veryHigh: return 5
        }
    }
    
    private func getAssetsPoints() -> Int {
        guard let cashAndLiquidAssets = self.signUpData.cashAndLiquidAssets else { return 0 }
        switch cashAndLiquidAssets {
        case .lessThan10k: return 0
        case .tenKToFiftyK: return 1
        case .fiftyKToTwoHundredK: return 2
        case .twoHundredKToFiveHundredK: return 3
        case .fiveHundredKToOneMillion: return 4
        case .oneMillionPlus: return 5
        }
    }
    
    private func getIncomeSourcesText() -> String {
        var sources: [String] = []
        if self.signUpData.incomeSources["Assets"] == true { sources.append("Assets") }
        if self.signUpData.incomeSources["Inheritance"] == true { sources.append("Inheritance") }
        if self.signUpData.incomeSources["Settlement"] == true { sources.append("Settlement") }
        return sources.isEmpty ? "None" : sources.joined(separator: ", ")
    }
    
    private func getIncomeSourcesPoints() -> Int {
        var points = 0
        if self.signUpData.incomeSources["Assets"] == true { points += 2 }
        if self.signUpData.incomeSources["Inheritance"] == true { points += 1 }
        if self.signUpData.incomeSources["Settlement"] == true { points += 1 }
        return points
    }
    
    private func getStocksPoints() -> Int {
        guard let stocksTransactionsCount = self.signUpData.stocksTransactionsCount else { return 0 }
        switch stocksTransactionsCount {
        case .none: return 0
        case .oneToTen: return 1
        case .tenToFifty: return 2
        case .fiftyPlus: return 3
        }
    }
    
    private func getETFsPoints() -> Int {
        guard let etfsTransactionsCount = self.signUpData.etfsTransactionsCount else { return 0 }
        switch etfsTransactionsCount {
        case .none: return 0
        case .oneToTen: return 1
        case .tenToTwenty: return 2
        case .moreThanTwenty: return 3
        }
    }
    
    private func getDerivativesPoints() -> Int {
        guard let derivativesTransactionsCount = self.signUpData.derivativesTransactionsCount else { return 0 }
        switch derivativesTransactionsCount {
        case .none: return 0
        case .oneToTen: return 3
        case .tenToFifty: return 6
        case .fiftyPlus: return 8
        }
    }
    
    private func getInvestmentAmountsText() -> String {
        let stocks = self.signUpData.stocksInvestmentAmount?.displayName ?? SignUpStepSelectionPrompt.pleaseSelect
        let etfs = self.signUpData.etfsInvestmentAmount?.displayName ?? SignUpStepSelectionPrompt.pleaseSelect
        let derivatives = self.signUpData.derivativesInvestmentAmount?.displayName ?? SignUpStepSelectionPrompt.pleaseSelect
        return "Stocks: \(stocks), ETFs: \(etfs), Derivatives: \(derivatives)"
    }
    
    private func getInvestmentAmountsPoints() -> Int {
        let stocksAmountScore: Int
        if let stocksInvestmentAmount = self.signUpData.stocksInvestmentAmount {
            switch stocksInvestmentAmount {
            case .hundredToTenThousand: stocksAmountScore = 0
            case .tenThousandToHundredThousand: stocksAmountScore = 1
            case .hundredThousandToMillion: stocksAmountScore = 2
            case .moreThanMillion: stocksAmountScore = 4
            }
        } else {
            stocksAmountScore = 0
        }
        
        let etfsAmountScore: Int
        if let etfsInvestmentAmount = self.signUpData.etfsInvestmentAmount {
            switch etfsInvestmentAmount {
            case .hundredToTenThousand: etfsAmountScore = 0
            case .tenThousandToHundredThousand: etfsAmountScore = 1
            case .hundredThousandToMillion: etfsAmountScore = 2
            case .moreThanMillion: etfsAmountScore = 4
            }
        } else {
            etfsAmountScore = 0
        }
        
        let derivativesAmountScore: Int
        if let derivativesInvestmentAmount = self.signUpData.derivativesInvestmentAmount {
            switch derivativesInvestmentAmount {
            case .zeroToThousand: derivativesAmountScore = 0
            case .thousandToTenThousand: derivativesAmountScore = 2
            case .tenThousandToHundredThousand: derivativesAmountScore = 4
            case .moreThanHundredThousand: derivativesAmountScore = 6
            }
        } else {
            derivativesAmountScore = 0
        }
        
        return max(stocksAmountScore, etfsAmountScore, derivativesAmountScore)
    }
    
    private func getHoldingPeriodPoints() -> Int {
        guard let derivativesHoldingPeriod = self.signUpData.derivativesHoldingPeriod else { return 0 }
        switch derivativesHoldingPeriod {
        case .monthsToYears: return 1
        case .daysToWeeks: return 2
        case .minutesToHours: return 4
        }
    }
    
    private func getReturnPoints() -> Int {
        switch self.signUpData.desiredReturn {
        case .atLeastTenPercent: return 1
        case .atLeastFiftyPercent: return 3
        case .atLeastHundredPercent: return 5
        }
    }
    
    private func getOtherAssetsText() -> String {
        var assets: [String] = []
        if self.signUpData.otherAssets["Real estate"] == true { assets.append("Real estate") }
        if self.signUpData.otherAssets["Gold, silver"] == true { assets.append("Gold, silver") }
        return assets.isEmpty ? "None" : assets.joined(separator: ", ")
    }
    
    private func getOtherAssetsPoints() -> Int {
        var points = 0
        if self.signUpData.otherAssets["Real estate"] == true { points += 2 }
        if self.signUpData.otherAssets["Gold, silver"] == true { points += 1 }
        return points
    }
    
    private func getTotalScore() -> Int {
        return self.getIncomePoints() + self.getAssetsPoints() + self.getIncomeSourcesPoints() + 
            self.getStocksPoints() + self.getETFsPoints() + self.getDerivativesPoints() + 
            self.getInvestmentAmountsPoints() + self.getHoldingPeriodPoints() + 
            self.getReturnPoints() + self.getOtherAssetsPoints()
    }
}

struct BreakdownRow: View {
    let title: String
    let value: String
    let points: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(self.title)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)
                
                Text(self.value)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }
            
            Spacer()
            
            Text("\(self.points) pts")
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.semibold)
                .foregroundColor(self.points > 0 ? AppTheme.accentLightBlue : AppTheme.fontColor.opacity(0.5))
        }
    }
}

#Preview {
    RiskClassCalculationBreakdownView(signUpData: SignUpData())
        .padding()
        .background(AppTheme.screenBackground)
}
