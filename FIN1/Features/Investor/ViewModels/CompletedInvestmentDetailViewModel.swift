import Foundation
import SwiftUI

// MARK: - Completed Investment Detail ViewModel
@MainActor
final class CompletedInvestmentDetailViewModel: ObservableObject {
    // MARK: - Dependencies
    private let investment: Investment
    private var poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)?
    private var tradeLifecycleService: (any TradeLifecycleServiceProtocol)?
    private var invoiceService: (any InvoiceServiceProtocol)?
    private var calculationService: (any InvestorCollectionBillCalculationServiceProtocol)?
    private var commissionCalculationService: (any CommissionCalculationServiceProtocol)?
    private var configurationService: (any ConfigurationServiceProtocol)?
    private var settlementAPIService: (any SettlementAPIServiceProtocol)?
    private var tradeAPIService: (any TradeAPIServiceProtocol)?

    // MARK: - Published
    @Published var tradeLineItems: [TradeLineItem] = []
    @Published private var statementSummary: InvestorInvestmentStatementSummary?
    @Published private var canonicalSummary: ServerInvestmentCanonicalSummary?
    @Published private var tradeLedReturnPercentageValue: Double?

    private var monetaryServerOnly: Bool {
        self.configurationService?.investorMonetaryServerOnly ?? true
    }

    // MARK: - Initialization
    init(investment: Investment) {
        self.investment = investment
    }

    // MARK: - Configuration

    func reconfigure(with services: AppServices) {
        self.poolTradeParticipationService = services.poolTradeParticipationService
        self.tradeLifecycleService = services.tradeLifecycleService
        self.invoiceService = services.invoiceService
        self.calculationService = InvestorCollectionBillCalculationService()
        self.commissionCalculationService = services.commissionCalculationService
        self.configurationService = services.configurationService
        self.settlementAPIService = services.settlementAPIService
        self.tradeAPIService = services.parseAPIClient.map { TradeAPIService(apiClient: $0) }
        self.refreshStatementSummary()
        self.refreshTradeLedReturnPercentage()
    }

    private func refreshStatementSummary() {
        guard let poolTradeParticipationService,
              let tradeLifecycleService,
              let invoiceService,
              let calculationService,
              let commissionCalculationService,
              let configurationService else {
            self.statementSummary = nil
            self.tradeLineItems = []
            return
        }

        let commissionRate = configurationService.effectiveInvestorCommissionRate
        let investmentId = self.investment.id
        let tradeAPI = self.tradeAPIService
        let localTrades = tradeLifecycleService.completedTrades

        Task { @MainActor [weak self] in
            guard let self else { return }
            let tradeIds = Set(
                poolTradeParticipationService.getParticipations(forInvestmentId: investmentId).map(\.tradeId)
            )
            let tradesById = await InvestorInvestmentStatementAggregator.resolveTradesForPoolParticipations(
                investedTradeIds: tradeIds,
                localTrades: localTrades,
                tradeAPIService: tradeAPI
            )
            self.rebuildTradeLineItems(additionalTradesById: tradesById)

            if let settlementAPIService = self.settlementAPIService {
                self.statementSummary = await InvestorInvestmentStatementAggregator.summarizeInvestmentFromServer(
                    investmentId: investmentId,
                    poolTradeParticipationService: poolTradeParticipationService,
                    tradeLifecycleService: tradeLifecycleService,
                    invoiceService: invoiceService,
                    settlementAPIService: settlementAPIService,
                    calculationService: calculationService,
                    commissionCalculationService: commissionCalculationService,
                    investment: self.investment,
                    additionalTradesById: tradesById,
                    commissionRate: commissionRate,
                    monetaryServerOnly: self.monetaryServerOnly,
                    collectionBillServerLegs: self.configurationService?.collectionBillServerLegs ?? true
                )
                self.canonicalSummary = await ServerCalculatedReturnResolver.resolveCanonicalSummary(
                    investmentId: investmentId,
                    settlementAPIService: settlementAPIService,
                    allowUnweightedReturnFallback: !self.monetaryServerOnly
                )
            } else {
                self.statementSummary = nil
                self.canonicalSummary = nil
            }
        }
    }

    // MARK: - Investment Metadata
    var investmentNumber: String {
        self.investment.canonicalDisplayReference
    }

    var traderName: String {
        self.investment.traderName
    }

    var traderSpecialization: String {
        self.investment.specialization
    }

    var statusText: String {
        self.investment.status.displayName
    }

    var statusColor: Color {
        switch self.investment.status {
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
        self.investment.createdAt.formatted(date: .abbreviated, time: .shortened)
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
        if self.investment.reservationStatus == .active || self.investment.reservationStatus == .executing {
            return "1"
        }
        return "0"
    }

    var completedInvestmentCountText: String {
        // Check this investment's reservation status
        if self.investment.reservationStatus == .completed {
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
        self.investment.amount
    }

    var investedAmountText: String {
        self.investedAmount.formattedAsLocalizedCurrency()
    }

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

    var currentValueText: String {
        self.currentValue.formattedAsLocalizedCurrency()
    }

    var profit: Double {
        if let statementSummary {
            return statementSummary.statementGrossProfit
        }
        if let canonical = canonicalSummary {
            return canonical.grossProfit
        }
        guard !self.monetaryServerOnly else { return 0 }
        return self.currentValue - self.investedAmount
    }

    var profitText: String {
        self.profit.formattedAsLocalizedCurrency()
    }

    var isProfitPositive: Bool {
        self.profit >= 0
    }

    var returnPercentage: Double {
        self.tradeLedReturnPercentageValue ?? 0.0
    }

    var returnPercentageText: String {
        guard let tradeLedReturnPercentageValue else { return "pending" }
        return NumberFormatter.localizedDecimalFormatter.string(for: tradeLedReturnPercentageValue).map { "\($0) %" } ?? "0,00 %"
    }

    var provisionAmount: Double {
        guard let configurationService else { return 0.0 }
        let rate = configurationService.effectiveAppServiceChargeRate
        return self.investedAmount * rate
    }

    var provisionAmountText: String {
        self.provisionAmount.formattedAsLocalizedCurrency()
    }

    // MARK: - Commission Calculation
    var commissionAmount: Double {
        guard self.profit > 0 else {
            return 0.0
        }
        guard let configurationService else { return 0.0 }
        let commissionRate = configurationService.effectiveInvestorCommissionRate
        return self.commissionCalculationService?.calculateCommission(
            grossProfit: self.profit,
            rate: commissionRate
        ) ?? 0.0
    }

    var commissionAmountText: String {
        self.commissionAmount.formattedAsLocalizedCurrency()
    }

    // MARK: - Tax Calculations
    private var capitalGainsTaxAmount: Double {
        InvoiceTaxCalculator.calculateCapitalGainsTax(for: max(self.profit, 0))
    }

    private var solidaritySurchargeAmount: Double {
        InvoiceTaxCalculator.calculateSolidaritySurcharge(for: self.capitalGainsTaxAmount)
    }

    private var churchTaxAmount: Double {
        InvoiceTaxCalculator.calculateChurchTax(for: self.capitalGainsTaxAmount)
    }

    var totalTaxAmount: Double {
        self.capitalGainsTaxAmount + self.solidaritySurchargeAmount + self.churchTaxAmount
    }

    var capitalGainsTaxText: String {
        self.capitalGainsTaxAmount.formattedAsLocalizedCurrency()
    }

    var solidaritySurchargeText: String {
        self.solidaritySurchargeAmount.formattedAsLocalizedCurrency()
    }

    var churchTaxText: String {
        self.churchTaxAmount.formattedAsLocalizedCurrency()
    }

    var totalTaxText: String {
        self.totalTaxAmount.formattedAsLocalizedCurrency()
    }

    // MARK: - Net Outcome
    var netProfitAfterCharges: Double {
        self.profit - self.totalTaxAmount - self.provisionAmount
    }

    var netProfitAfterChargesText: String {
        self.netProfitAfterCharges.formattedAsLocalizedCurrency()
    }

    var hasPositiveNetProfit: Bool {
        self.netProfitAfterCharges >= 0
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
        switch self.investment.reservationStatus {
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
            id: self.investment.id,
            sequenceNumber: self.investment.sequenceNumber ?? 1,
            statusText: self.investment.reservationStatus.displayName,
            statusColor: statusColor,
            amountText: self.investment.amount.formattedAsLocalizedCurrency(),
            isLocked: self.investment.reservationStatus != .reserved
        )]
    }

    var hasInvestmentDetails: Bool {
        !self.investmentDetails.isEmpty
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
            NumberFormatter.localizedDecimalFormatter.string(for: self.quantity) ?? "0,00"
        }

        var formattedUnitPrice: String {
            self.unitPrice.formattedAsLocalizedCurrency()
        }

        var formattedTotalAmount: String {
            self.totalAmount.formattedAsLocalizedCurrency()
        }
    }

    /// Total investor quantity across all trades for this investment
    var totalInvestorQuantity: Double {
        self.tradeLineItems.reduce(0) { $0 + $1.quantity }
    }

    var totalInvestorQuantityText: String {
        NumberFormatter.localizedDecimalFormatter.string(for: self.totalInvestorQuantity) ?? "0,00"
    }

    private func rebuildTradeLineItems(additionalTradesById: [String: Trade] = [:]) {
        guard
            let poolTradeParticipationService,
            let tradeLifecycleService
        else {
            self.tradeLineItems = []
            return
        }

        let participations = poolTradeParticipationService.getParticipations(forInvestmentId: self.investment.id)
        guard !participations.isEmpty else {
            self.tradeLineItems = []
            return
        }

        let trades = tradeLifecycleService.completedTrades
        var items: [TradeLineItem] = []

        for participation in participations {
            let trade = trades.first(where: { $0.id == participation.tradeId })
                ?? additionalTradesById[participation.tradeId]
            guard let trade else { continue }

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

        self.tradeLineItems = items.sorted { $0.tradeDate < $1.tradeDate }
    }

    private func refreshTradeLedReturnPercentage() {
        guard self.poolTradeParticipationService != nil,
              self.tradeLifecycleService != nil else {
            self.tradeLedReturnPercentageValue = nil
            return
        }

        let allowFallback = !(configurationService?.investorMonetaryServerOnly ?? true)
        Task {
            if let summary = await ServerCalculatedReturnResolver.resolveCanonicalSummary(
                investmentId: self.investment.id,
                settlementAPIService: self.settlementAPIService,
                allowUnweightedReturnFallback: allowFallback
            ), summary.hasReturnPercentage {
                self.tradeLedReturnPercentageValue = summary.returnPercentage
            } else {
                self.tradeLedReturnPercentageValue = nil
            }
        }
    }
}
