import Foundation

// MARK: - Admin Summary Report Model

struct AdminSummaryReport {
    let totalInvestments: Int
    let totalTrades: Int
    let totalInvestedAmount: Double
    let totalCurrentValue: Double
    let totalGrossProfit: Double
    let totalCommission: Double
    let totalTradeVolume: Double
    let totalTradeProfit: Double
    let investments: [AdminInvestmentSummary]
    let trades: [AdminTradeSummary]
    let generatedAt: Date

    static var empty: AdminSummaryReport {
        AdminSummaryReport(
            totalInvestments: 0,
            totalTrades: 0,
            totalInvestedAmount: 0,
            totalCurrentValue: 0,
            totalGrossProfit: 0,
            totalCommission: 0,
            totalTradeVolume: 0,
            totalTradeProfit: 0,
            investments: [],
            trades: [],
            generatedAt: Date()
        )
    }

    var netReturn: Double {
        guard self.totalInvestedAmount > 0 else { return 0 }
        return ((self.totalCurrentValue - self.totalInvestedAmount) / self.totalInvestedAmount) * 100
    }

    var averageReturnPerInvestment: Double {
        guard self.totalInvestments > 0 else { return 0 }
        return self.totalGrossProfit / Double(self.totalInvestments)
    }
}

// MARK: - Investment Summary

struct AdminInvestmentSummary: Identifiable {
    let id: String
    let investmentId: String
    let investmentNumber: String
    let investorId: String
    let investorName: String
    let traderId: String
    let traderName: String
    let amount: Double
    let currentValue: Double
    let grossProfit: Double
    let returnPercentage: Double?
    let commission: Double
    let tradeNumbers: [Int]
    let completedAt: Date
    let status: InvestmentStatus

    init(
        investmentId: String,
        investmentNumber: String,
        investorId: String,
        investorName: String,
        traderId: String,
        traderName: String,
        amount: Double,
        currentValue: Double,
        grossProfit: Double,
        returnPercentage: Double?,
        commission: Double,
        tradeNumbers: [Int],
        completedAt: Date,
        status: InvestmentStatus
    ) {
        self.id = investmentId
        self.investmentId = investmentId
        self.investmentNumber = investmentNumber
        self.investorId = investorId
        self.investorName = investorName
        self.traderId = traderId
        self.traderName = traderName
        self.amount = amount
        self.currentValue = currentValue
        self.grossProfit = grossProfit
        self.returnPercentage = returnPercentage
        self.commission = commission
        self.tradeNumbers = tradeNumbers
        self.completedAt = completedAt
        self.status = status
    }

    var tradeNumbersText: String {
        self.tradeNumbers.map { String(format: "%03d", $0) }.joined(separator: ", ")
    }
}

// MARK: - Trade Summary

struct AdminTradeSummary: Identifiable {
    let id: String
    let tradeId: String
    let tradeNumber: Int
    let symbol: String
    let traderId: String
    let buyAmount: Double
    let sellAmount: Double
    let profit: Double
    let investorIds: [String]
    let completedAt: Date

    init(
        tradeId: String,
        tradeNumber: Int,
        symbol: String,
        traderId: String,
        buyAmount: Double,
        sellAmount: Double,
        profit: Double,
        investorIds: [String],
        completedAt: Date
    ) {
        self.id = tradeId
        self.tradeId = tradeId
        self.tradeNumber = tradeNumber
        self.symbol = symbol
        self.traderId = traderId
        self.buyAmount = buyAmount
        self.sellAmount = sellAmount
        self.profit = profit
        self.investorIds = investorIds
        self.completedAt = completedAt
    }

    var tradeNumberText: String {
        String(format: "%03d", self.tradeNumber)
    }

    var investorCount: Int {
        self.investorIds.count
    }
}











