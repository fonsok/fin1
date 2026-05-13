import Foundation

// MARK: - Statement Item Model
struct InvestorInvestmentStatementItem: Identifiable {
    let id: String
    let tradeNumber: Int
    let symbol: String
    let tradeDate: Date

    // Buy leg (scaled)
    let buyQuantity: Double
    let buyPrice: Double
    let buyTotal: Double
    let buyFees: Double
    let buyFeeDetails: [InvestorFeeDetail]

    // Sell leg aggregated across partial sells (scaled)
    let sellQuantity: Double
    let sellAveragePrice: Double
    let sellTotal: Double
    let sellFees: Double
    let sellFeeDetails: [InvestorFeeDetail]

    // Derived amounts
    let grossProfit: Double
    let ownershipPercentage: Double
    let roiGrossProfit: Double
    let roiInvestedAmount: Double

    // Trade's ROI - same for all participants (trader and investors)
    let tradeROI: Double

    // Commission and profit after commission
    let commission: Double
    let grossProfitAfterCommission: Double

    // Residual amount (leftover after rounding quantity to whole number)
    let residualAmount: Double

    @MainActor
    static func build(
        trade: Trade,
        buyInvoice: Invoice?,
        sellInvoices: [Invoice],
        ownershipPercentage: Double,
        investorAllocatedAmount: Double,
        investmentCapitalAmount: Double,
        calculationService: any InvestorCollectionBillCalculationServiceProtocol,
        commissionCalculationService: any CommissionCalculationServiceProtocol,
        commissionRate: Double
    ) throws -> InvestorInvestmentStatementItem {
        let input = InvestorCollectionBillInput(
            investmentCapital: investmentCapitalAmount,
            buyPrice: trade.entryPrice,
            tradeTotalQuantity: trade.totalQuantity,
            ownershipPercentage: ownershipPercentage,
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices,
            investorAllocatedAmount: investorAllocatedAmount
        )

        let output = try calculationService.calculateCollectionBill(input: input)

        let commission = commissionCalculationService.calculateCommission(
            grossProfit: output.grossProfit,
            rate: commissionRate
        )
        let grossProfitAfterCommission = commissionCalculationService.calculateNetProfitAfterCommission(
            grossProfit: output.grossProfit,
            rate: commissionRate
        )

        return InvestorInvestmentStatementItem(
            id: trade.id,
            tradeNumber: trade.tradeNumber,
            symbol: trade.symbol,
            tradeDate: trade.completedAt ?? trade.updatedAt,
            buyQuantity: output.buyQuantity,
            buyPrice: output.buyPrice,
            buyTotal: output.buyAmount,
            buyFees: output.buyFees,
            buyFeeDetails: output.buyFeeDetails,
            sellQuantity: output.sellQuantity,
            sellAveragePrice: output.sellAveragePrice,
            sellTotal: output.sellAmount,
            sellFees: output.sellFees,
            sellFeeDetails: output.sellFeeDetails,
            grossProfit: output.grossProfit,
            ownershipPercentage: ownershipPercentage,
            roiGrossProfit: output.roiGrossProfit,
            roiInvestedAmount: output.roiInvestedAmount,
            tradeROI: trade.displayROI,
            commission: commission,
            grossProfitAfterCommission: grossProfitAfterCommission,
            residualAmount: output.residualAmount
        )
    }

    static func build(
        trade: Trade,
        buyInvoice: Invoice?,
        sellInvoices: [Invoice],
        ownershipPercentage: Double,
        investorAllocatedAmount: Double,
        commissionCalculationService: any CommissionCalculationServiceProtocol = CommissionCalculationService(),
        commissionRate: Double
    ) -> InvestorInvestmentStatementItem {
        let buyPrice = trade.entryPrice
        let investorBuyQty = trade.totalQuantity * ownershipPercentage
        let buyTotal = (buyInvoice?.securitiesTotal ?? 0.0) * ownershipPercentage
        let buyQty = investorBuyQty
        let roiInvestedAmount = investorBuyQty * buyPrice
        let buyFeeDetails = self.buildFeeDetails(from: buyInvoice, scale: ownershipPercentage)
        let buyFeesInvestor = buyFeeDetails.reduce(0) { $0 + $1.amount }

        let totalSellQtyFromInvoices = sellInvoices.reduce(0.0) { total, invoice in
            total + invoice.securitiesItems.reduce(0.0) { $0 + $1.quantity }
        }
        let totalSellValueFromInvoices = sellInvoices.reduce(0.0) { total, invoice in
            total + invoice.securitiesTotal
        }

        let sellPercentage = trade.totalQuantity > 0 ? (totalSellQtyFromInvoices / trade.totalQuantity) : 0.0
        let investorSellQty = investorBuyQty * sellPercentage
        let sellAvgPrice = totalSellQtyFromInvoices > 0 ? totalSellValueFromInvoices / totalSellQtyFromInvoices : 0.0
        let investorSellValue = totalSellValueFromInvoices * ownershipPercentage

        let sellShare = totalSellValueFromInvoices > 0 ? (investorSellValue / totalSellValueFromInvoices) : ownershipPercentage
        let sellFeeDetails = self.buildFeeDetails(from: sellInvoices, scale: sellShare)
        let investorSellFees = sellFeeDetails.reduce(0) { $0 + $1.amount }

        let grossProfit = investorSellValue - investorSellFees - (buyTotal + buyFeesInvestor)
        let roiGrossProfit = investorSellValue - roiInvestedAmount

        let commission = commissionCalculationService.calculateCommission(
            grossProfit: grossProfit,
            rate: commissionRate
        )
        let grossProfitAfterCommission = commissionCalculationService.calculateNetProfitAfterCommission(
            grossProfit: grossProfit,
            rate: commissionRate
        )

        return InvestorInvestmentStatementItem(
            id: trade.id,
            tradeNumber: trade.tradeNumber,
            symbol: trade.symbol,
            tradeDate: trade.completedAt ?? trade.updatedAt,
            buyQuantity: buyQty,
            buyPrice: buyPrice,
            buyTotal: buyTotal,
            buyFees: buyFeesInvestor,
            buyFeeDetails: buyFeeDetails,
            sellQuantity: investorSellQty,
            sellAveragePrice: sellAvgPrice,
            sellTotal: investorSellValue,
            sellFees: investorSellFees,
            sellFeeDetails: sellFeeDetails,
            grossProfit: grossProfit,
            ownershipPercentage: ownershipPercentage,
            roiGrossProfit: roiGrossProfit,
            roiInvestedAmount: roiInvestedAmount,
            tradeROI: trade.displayROI,
            commission: commission,
            grossProfitAfterCommission: grossProfitAfterCommission,
            residualAmount: 0.0
        )
    }

    private static func buildFeeDetails(from invoice: Invoice?, scale: Double) -> [InvestorFeeDetail] {
        guard let invoice = invoice else { return [] }
        return self.buildFeeDetails(from: [invoice], scale: scale)
    }

    private static func buildFeeDetails(from invoices: [Invoice], scale: Double) -> [InvestorFeeDetail] {
        guard scale > 0 else { return [] }
        return invoices.flatMap { invoice -> [InvestorFeeDetail] in
            invoice.items
                .filter { $0.itemType != .securities }
                .map { item in
                    InvestorFeeDetail(
                        label: item.description,
                        amount: item.totalAmount * scale
                    )
                }
        }
        .filter { abs($0.amount) > 0.0001 }
    }
}

struct InvestorFeeDetail: Identifiable {
    let id = UUID()
    let label: String
    let amount: Double
    var percentageRate: String?

    init(label: String, amount: Double, percentageRate: String? = nil) {
        self.label = label
        self.amount = amount
        self.percentageRate = percentageRate
    }
}
