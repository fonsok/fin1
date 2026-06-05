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

    // Canonical ledger totals (from ``InvestorCollectionBillOutput`` — do not recompute in UI)
    let totalBuyCost: Double
    let netSellAmount: Double

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
    /// Auszahlung: Net Sell Amount − Commission.
    let transferAmount: Double

    /// Erklärzeile für die Collection Bill (Net Sell − Commission).
    var transferAmountCalculationNote: String {
        let net = self.netSellAmount.formattedAsLocalizedCurrency()
        let comm = self.commission.formattedAsLocalizedCurrency()
        let total = self.transferAmount.formattedAsLocalizedCurrency()
        return "(Net Sell Amount - Commission = \(net) - \(comm) = \(total))"
    }

    // Residual amount (leftover after rounding quantity to whole number)
    let residualAmount: Double

    /// GoB Belegnummer when row comes from server `investorCollectionBill`.
    let accountingDocumentNumber: String?
    /// Set when archived Beleg legs and booked summary diverge.
    let belegInconsistencyMessage: String?
    /// False for server Beleg rows; true for local preview / network fallback.
    let isProvisionalLocalEstimate: Bool

    /// Fee magnitude for display in the Sell Fees row.
    var sellFeesDisplayAmount: Double { abs(self.sellFees) }

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
        return self.from(
            trade: trade,
            output: output,
            ownershipPercentage: ownershipPercentage,
            commissionCalculationService: commissionCalculationService,
            commissionRate: commissionRate
        )
    }

    @MainActor
    static func from(
        trade: Trade,
        output: InvestorCollectionBillOutput,
        ownershipPercentage: Double,
        commissionCalculationService: any CommissionCalculationServiceProtocol,
        commissionRate: Double
    ) -> InvestorInvestmentStatementItem {
        let commission = output.bookedCommission
            ?? commissionCalculationService.calculateCommission(grossProfit: output.grossProfit, rate: commissionRate)
        let grossProfitAfterCommission = output.bookedNetProfit
            ?? commissionCalculationService.calculateNetProfitAfterCommission(
                grossProfit: output.grossProfit,
                rate: commissionRate
            )
        let transferAmount = output.bookedTransferAmount
            ?? max(0, output.netSellAmount - commission)

        #if DEBUG
        if abs(output.grossProfit - (output.netSellAmount - output.totalBuyCost)) >= 0.02 {
            InvestorCollectionBillLog.warning(
                "Ledger identity violated: gross=\(output.grossProfit) netSell=\(output.netSellAmount) buyCost=\(output.totalBuyCost)"
            )
        }
        #endif

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
            totalBuyCost: output.totalBuyCost,
            netSellAmount: output.netSellAmount,
            grossProfit: output.grossProfit,
            ownershipPercentage: ownershipPercentage,
            roiGrossProfit: output.roiGrossProfit,
            roiInvestedAmount: output.roiInvestedAmount,
            tradeROI: trade.displayROI,
            commission: commission,
            grossProfitAfterCommission: grossProfitAfterCommission,
            transferAmount: transferAmount,
            residualAmount: output.residualAmount,
            accountingDocumentNumber: output.accountingDocumentNumber,
            belegInconsistencyMessage: output.belegInconsistencyMessage,
            isProvisionalLocalEstimate: !output.isFromArchivedBeleg
        )
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
