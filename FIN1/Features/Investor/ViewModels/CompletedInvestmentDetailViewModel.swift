import SwiftUI
import Foundation

// MARK: - Completed Investment Detail ViewModel
@MainActor
final class CompletedInvestmentDetailViewModel: ObservableObject {
    // MARK: - Dependencies
    private let investment: Investment
    private var poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)?
    private var tradeLifecycleService: (any TradeLifecycleServiceProtocol)?
    private var invoiceService: (any InvoiceServiceProtocol)?
    private var investmentService: (any InvestmentServiceProtocol)?
    private var calculationService: (any InvestorCollectionBillCalculationServiceProtocol)?
    private var commissionCalculationService: (any CommissionCalculationServiceProtocol)?
    private var configurationService: (any ConfigurationServiceProtocol)?

    // MARK: - Published
    @Published var tradeLineItems: [TradeLineItem] = []
    @Published private var statementSummary: InvestorInvestmentStatementSummary?

    // MARK: - Initialization
    init(investment: Investment) {
        self.investment = investment
    }

    // MARK: - Configuration

    func reconfigure(with services: AppServices) {
        poolTradeParticipationService = services.poolTradeParticipationService
        tradeLifecycleService = services.tradeLifecycleService
        invoiceService = services.invoiceService
        investmentService = services.investmentService
        calculationService = InvestorCollectionBillCalculationService()
        commissionCalculationService = services.commissionCalculationService
        configurationService = services.configurationService
        rebuildTradeLineItems()
        refreshStatementSummary()
    }

    private func refreshStatementSummary() {
        guard let poolTradeParticipationService,
              let tradeLifecycleService,
              let invoiceService,
              let investmentService,
              let calculationService,
              let commissionCalculationService else {
            statementSummary = nil
            return
        }

        let commissionRate = configurationService?.traderCommissionRate ?? CalculationConstants.FeeRates.traderCommissionRate
        statementSummary = InvestorInvestmentStatementAggregator.summarizeInvestment(
            investmentId: investment.id,
            poolTradeParticipationService: poolTradeParticipationService,
            tradeLifecycleService: tradeLifecycleService,
            invoiceService: invoiceService,
            investmentService: investmentService,
            calculationService: calculationService,
            commissionCalculationService: commissionCalculationService,
            commissionRate: commissionRate
        )
    }

    // MARK: - Investment Metadata
    var investmentNumber: String {
        investment.id.extractInvestmentNumber()
    }

    var traderName: String {
        investment.traderName
    }

    var traderSpecialization: String {
        investment.specialization
    }

    var statusText: String {
        investment.status.displayName
    }

    var statusColor: Color {
        switch investment.status {
        case .completed:
            return AppTheme.accentLightBlue
        case .cancelled:
            return AppTheme.accentRed
        case .active, .submitted:
            return AppTheme.accentGreen
        }
    }

    var completedDateText: String {
        guard let completedAt = investment.completedAt else {
            return "—"
        }
        return completedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var createdDateText: String {
        investment.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    var numberOfInvestmentsText: String {
        // Show sequence number if available
        if let sequenceNumber = investment.sequenceNumber {
            return "\(sequenceNumber)"
        }
        return "1"
    }

    var activeInvestmentCountText: String {
        // Check this investment's reservation status
        if investment.reservationStatus == .active || investment.reservationStatus == .executing {
            return "1"
        }
        return "0"
    }

    var completedInvestmentCountText: String {
        // Check this investment's reservation status
        if investment.reservationStatus == .completed {
            return "1"
        }
        return "0"
    }

    var tradeNumberText: String {
        // Get the trade number from the first trade line item (there should only be one)
        guard let firstTrade = tradeLineItems.first else {
            return "—"
        }
        return String(format: "%03d", firstTrade.tradeNumber)
    }

    // MARK: - Financial Metrics
    var investedAmount: Double {
        investment.amount
    }

    var investedAmountText: String {
        investedAmount.formattedAsLocalizedCurrency()
    }

    var currentValue: Double {
        // Use statement-based calculation if available (same as table), otherwise fallback to investment.currentValue
        if let statementSummary = statementSummary {
            // Current value = invested amount + gross profit from statement
            return investedAmount + statementSummary.statementGrossProfit
        }
        // Fallback to stored value if statement not available yet
        return investment.currentValue
    }

    var currentValueText: String {
        currentValue.formattedAsLocalizedCurrency()
    }

    var profit: Double {
        // Use statement-based gross profit (same as table) for consistency
        if let statementSummary = statementSummary {
            return statementSummary.statementGrossProfit
        }
        // Fallback to simple calculation if statement not available yet
        return currentValue - investedAmount
    }

    var profitText: String {
        profit.formattedAsLocalizedCurrency()
    }

    var isProfitPositive: Bool {
        profit >= 0
    }

    var returnPercentage: Double {
        investment.performance
    }

    var returnPercentageText: String {
        NumberFormatter.localizedDecimalFormatter.string(for: returnPercentage).map { "\($0) %" } ?? "0,00 %"
    }

    var provisionAmount: Double {
        let rate = configurationService?.effectivePlatformServiceChargeRate ?? CalculationConstants.ServiceCharges.platformServiceChargeRate
        return investedAmount * rate
    }

    var provisionAmountText: String {
        provisionAmount.formattedAsLocalizedCurrency()
    }

    // MARK: - Commission Calculation
    /// Calculates trader commission as 10% of the displayed profit (net profit)
    /// The displayed profit is what the investor received after commission was deducted
    /// Commission is shown as 10% of the investor's profit for transparency
    var commissionAmount: Double {
        guard profit > 0 else {
            return 0.0 // No commission on losses or zero profit
        }
        // Use centralized commission calculation service
        let commissionRate = CalculationConstants.FeeRates.traderCommissionRate
        return commissionCalculationService?.calculateCommission(
            grossProfit: profit,
            rate: commissionRate
        ) ?? 0.0
    }

    var commissionAmountText: String {
        commissionAmount.formattedAsLocalizedCurrency()
    }

    // MARK: - Tax Calculations
    private var capitalGainsTaxAmount: Double {
        InvoiceTaxCalculator.calculateCapitalGainsTax(for: max(profit, 0))
    }

    private var solidaritySurchargeAmount: Double {
        InvoiceTaxCalculator.calculateSolidaritySurcharge(for: capitalGainsTaxAmount)
    }

    private var churchTaxAmount: Double {
        InvoiceTaxCalculator.calculateChurchTax(for: capitalGainsTaxAmount)
    }

    var totalTaxAmount: Double {
        capitalGainsTaxAmount + solidaritySurchargeAmount + churchTaxAmount
    }

    var capitalGainsTaxText: String {
        capitalGainsTaxAmount.formattedAsLocalizedCurrency()
    }

    var solidaritySurchargeText: String {
        solidaritySurchargeAmount.formattedAsLocalizedCurrency()
    }

    var churchTaxText: String {
        churchTaxAmount.formattedAsLocalizedCurrency()
    }

    var totalTaxText: String {
        totalTaxAmount.formattedAsLocalizedCurrency()
    }

    // MARK: - Net Outcome
    var netProfitAfterCharges: Double {
        profit - totalTaxAmount - provisionAmount
    }

    var netProfitAfterChargesText: String {
        netProfitAfterCharges.formattedAsLocalizedCurrency()
    }

    var hasPositiveNetProfit: Bool {
        netProfitAfterCharges >= 0
    }

    // MARK: - Investment Details
    struct InvestmentDetail: Identifiable {
        let id: String
        let sequenceNumber: Int
        let statusText: String
        let statusColor: Color
        let amountText: String
        let isLocked: Bool
    }

    var investmentDetails: [InvestmentDetail] {
        // Create a single investment detail from the investment
        let statusColor: Color
        switch investment.reservationStatus {
        case .completed:
            statusColor = AppTheme.accentLightBlue
        case .active, .executing:
            statusColor = AppTheme.accentGreen
        case .reserved:
            statusColor = AppTheme.fontColor.opacity(0.8)
        case .closed:
            statusColor = AppTheme.accentOrange
        case .cancelled:
            statusColor = AppTheme.accentRed
        }

        return [InvestmentDetail(
            id: investment.id,
            sequenceNumber: investment.sequenceNumber ?? 1,
            statusText: investment.reservationStatus.displayName,
            statusColor: statusColor,
            amountText: investment.amount.formattedAsLocalizedCurrency(),
            isLocked: investment.reservationStatus != .reserved
        )]
    }

    var hasInvestmentDetails: Bool {
        !investmentDetails.isEmpty
    }

    // MARK: - Investor Trade Lines

    struct TradeLineItem: Identifiable {
        let id: String
        let tradeNumber: Int
        let symbol: String
        let tradeDate: Date
        let quantity: Double
        let unitPrice: Double
        let totalAmount: Double

        var formattedQuantity: String {
            NumberFormatter.localizedDecimalFormatter.string(for: quantity) ?? "0,00"
        }

        var formattedUnitPrice: String {
            unitPrice.formattedAsLocalizedCurrency()
        }

        var formattedTotalAmount: String {
            totalAmount.formattedAsLocalizedCurrency()
        }
    }

    /// Total investor quantity across all trades for this investment
    var totalInvestorQuantity: Double {
        tradeLineItems.reduce(0) { $0 + $1.quantity }
    }

    var totalInvestorQuantityText: String {
        NumberFormatter.localizedDecimalFormatter.string(for: totalInvestorQuantity) ?? "0,00"
    }

    private func rebuildTradeLineItems() {
        guard
            let poolTradeParticipationService,
            let tradeLifecycleService
        else {
            tradeLineItems = []
            return
        }

        let participations = poolTradeParticipationService.getParticipations(forInvestmentId: investment.id)
        guard !participations.isEmpty else {
            tradeLineItems = []
            return
        }

        let trades = tradeLifecycleService.completedTrades
        var items: [TradeLineItem] = []

        for participation in participations {
            guard let trade = trades.first(where: { $0.id == participation.tradeId }) else { continue }

            let unitPrice = trade.entryPrice
            guard unitPrice > 0 else { continue }

            let quantity = participation.allocatedAmount / unitPrice
            let totalAmount = quantity * unitPrice

            let item = TradeLineItem(
                id: participation.id,
                tradeNumber: trade.tradeNumber,
                symbol: trade.symbol,
                tradeDate: trade.completedAt ?? trade.updatedAt,
                quantity: quantity,
                unitPrice: unitPrice,
                totalAmount: totalAmount
            )
            items.append(item)
        }

        tradeLineItems = items.sorted { $0.tradeDate < $1.tradeDate }
    }
}
