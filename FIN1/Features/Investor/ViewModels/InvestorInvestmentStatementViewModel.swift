import SwiftUI
import Foundation

// MARK: - Investor Investment Statement ViewModel
/// Builds an investor-focused statement view for a single investment,
/// using the investor's actual investment capital (source of truth) for calculations.
@MainActor
final class InvestorInvestmentStatementViewModel: ObservableObject {
    // MARK: - Dependencies
    let investment: Investment
    private let poolTradeParticipationService: any PoolTradeParticipationServiceProtocol
    private let tradeService: any TradeLifecycleServiceProtocol
    private let invoiceService: any InvoiceServiceProtocol
    private let calculationService: any InvestorCollectionBillCalculationServiceProtocol
    private let commissionCalculationService: any CommissionCalculationServiceProtocol
    private let configurationService: any ConfigurationServiceProtocol
    private let settlementAPIService: (any SettlementAPIServiceProtocol)?

    // MARK: - Published Data
    @Published var statementItems: [InvestorInvestmentStatementItem] = []
    /// True while fetching backend-authoritative collection bill data
    @Published private(set) var isRefreshingFromBackend = false
    /// When non-nil, backend fetch failed; user is seeing local/cached data
    @Published private(set) var backendRefreshMessage: String?

    // MARK: - Document Number
    /// Eindeutige Belegnummer für dieses Collection Bill Dokument (gemäß GoB)
    var documentNumber: String?

    /// Admin-configured commission rate (single source of truth via ConfigurationService)
    var effectiveCommissionRate: Double {
        configurationService.effectiveCommissionRate
    }

    // MARK: - Initialization
    init(
        investment: Investment,
        poolTradeParticipationService: any PoolTradeParticipationServiceProtocol,
        tradeService: any TradeLifecycleServiceProtocol,
        invoiceService: any InvoiceServiceProtocol,
        calculationService: any InvestorCollectionBillCalculationServiceProtocol = InvestorCollectionBillCalculationService(),
        commissionCalculationService: any CommissionCalculationServiceProtocol = CommissionCalculationService(),
        configurationService: any ConfigurationServiceProtocol,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil
    ) {
        self.investment = investment
        self.poolTradeParticipationService = poolTradeParticipationService
        self.tradeService = tradeService
        self.invoiceService = invoiceService
        self.calculationService = calculationService
        self.commissionCalculationService = commissionCalculationService
        self.configurationService = configurationService
        self.settlementAPIService = settlementAPIService

        rebuildStatement()
    }

    // MARK: - Public

    func rebuildStatement() {
        let participations = poolTradeParticipationService.getParticipations(forInvestmentId: investment.id)
        guard !participations.isEmpty else {
            statementItems = []
            return
        }

        // Get total investment capital (source of truth)
        let totalInvestmentCapital = investment.amount
        print("💰 InvestorInvestmentStatementViewModel: Investment capital (source of truth): €\(String(format: "%.2f", totalInvestmentCapital))")

        let trades = tradeService.completedTrades
        var items: [InvestorInvestmentStatementItem] = []

        let effectiveRate = effectiveCommissionRate
        print("💰 InvestorInvestmentStatementViewModel: Using commission rate: \(String(format: "%.0f", effectiveRate * 100))%")

        for participation in participations {
            guard let trade = trades.first(where: { $0.id == participation.tradeId }) else { continue }

            let allInvoices = invoiceService.getInvoicesForTrade(trade.id)
            let buyInvoice = allInvoices.first { $0.transactionType == .buy }
            let sellInvoices = allInvoices.filter { $0.transactionType == .sell }

            // Calculate this trade's share of investment capital
            // For single trade: use full investment capital
            // For multiple trades: distribute proportionally by ownership percentage
            let tradeCapitalShare: Double
            if participations.count == 1 {
                tradeCapitalShare = totalInvestmentCapital
            } else {
                let totalOwnership = participations.reduce(0.0) { $0 + $1.ownershipPercentage }
                tradeCapitalShare = totalOwnership > 0
                    ? (totalInvestmentCapital * participation.ownershipPercentage / totalOwnership)
                    : (totalInvestmentCapital / Double(participations.count))
            }

            print("💰 InvestorInvestmentStatementViewModel: Trade \(trade.tradeNumber) capital share: €\(String(format: "%.2f", tradeCapitalShare))")

            do {
                let item = try InvestorInvestmentStatementItem.build(
                    trade: trade,
                    buyInvoice: buyInvoice,
                    sellInvoices: sellInvoices,
                    ownershipPercentage: participation.ownershipPercentage,
                    investorAllocatedAmount: participation.allocatedAmount,
                    investmentCapitalAmount: tradeCapitalShare,
                    calculationService: calculationService,
                    commissionCalculationService: commissionCalculationService,
                    commissionRate: effectiveRate
                )
                items.append(item)
            } catch {
                print("❌ InvestorInvestmentStatementViewModel: Failed to build statement item for trade \(trade.tradeNumber): \(error)")
                // Fallback to legacy method if calculation service fails
                let legacyItem = InvestorInvestmentStatementItem.build(
                    trade: trade,
                    buyInvoice: buyInvoice,
                    sellInvoices: sellInvoices,
                    ownershipPercentage: participation.ownershipPercentage,
                    investorAllocatedAmount: participation.allocatedAmount,
                    commissionCalculationService: commissionCalculationService,
                    commissionRate: effectiveRate
                )
                items.append(legacyItem)
            }
        }

        // Sort statement items by trade completion date
        statementItems = items.sorted { lhs, rhs in
            lhs.tradeDate < rhs.tradeDate
        }
    }

    /// Refreshes statement items using backend-authoritative collection bill data where available.
    func refreshFromBackend() async {
        guard settlementAPIService != nil else { return }

        isRefreshingFromBackend = true
        backendRefreshMessage = nil
        defer { isRefreshingFromBackend = false }

        let participations = poolTradeParticipationService.getParticipations(forInvestmentId: investment.id)
        guard !participations.isEmpty else { return }

        let totalInvestmentCapital = investment.amount
        let trades = tradeService.completedTrades
        var items: [InvestorInvestmentStatementItem] = []
        let effectiveRate = effectiveCommissionRate

        for participation in participations {
            guard let trade = trades.first(where: { $0.id == participation.tradeId }) else { continue }

            let allInvoices = invoiceService.getInvoicesForTrade(trade.id)
            let buyInvoice = allInvoices.first { $0.transactionType == .buy }
            let sellInvoices = allInvoices.filter { $0.transactionType == .sell }

            let tradeCapitalShare: Double
            if participations.count == 1 {
                tradeCapitalShare = totalInvestmentCapital
            } else {
                let totalOwnership = participations.reduce(0.0) { $0 + $1.ownershipPercentage }
                tradeCapitalShare = totalOwnership > 0
                    ? (totalInvestmentCapital * participation.ownershipPercentage / totalOwnership)
                    : (totalInvestmentCapital / Double(participations.count))
            }

            let input = InvestorCollectionBillInput(
                investmentCapital: tradeCapitalShare,
                buyPrice: trade.entryPrice,
                tradeTotalQuantity: trade.totalQuantity,
                ownershipPercentage: participation.ownershipPercentage,
                buyInvoice: buyInvoice,
                sellInvoices: sellInvoices,
                investorAllocatedAmount: participation.allocatedAmount
            )

            do {
                let output = try await calculationService.calculateCollectionBillWithBackend(
                    input: input,
                    settlementAPIService: settlementAPIService,
                    tradeId: trade.id,
                    investmentId: investment.id,
                    onUsedLocalFallback: { [weak self] in
                        Task { @MainActor in
                            self?.backendRefreshMessage = "Daten werden aus dem lokalen Speicher angezeigt (Server nicht erreichbar)"
                        }
                    }
                )

                let commission = commissionCalculationService.calculateCommission(
                    grossProfit: output.grossProfit,
                    rate: effectiveRate
                )
                let netAfterComm = commissionCalculationService.calculateNetProfitAfterCommission(
                    grossProfit: output.grossProfit,
                    rate: effectiveRate
                )

                let item = InvestorInvestmentStatementItem(
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
                    ownershipPercentage: participation.ownershipPercentage,
                    roiGrossProfit: output.roiGrossProfit,
                    roiInvestedAmount: output.roiInvestedAmount,
                    tradeROI: trade.displayROI,
                    commission: commission,
                    grossProfitAfterCommission: netAfterComm,
                    residualAmount: output.residualAmount
                )
                items.append(item)
            } catch {
                print("⚠️ Backend refresh failed for trade \(trade.tradeNumber): \(error.localizedDescription)")
            }
        }

        if !items.isEmpty {
            statementItems = items.sorted { $0.tradeDate < $1.tradeDate }
        }
    }
}

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
    // This is the trade's performance percentage, not individual calculation
    let tradeROI: Double

    // Commission and profit after commission
    let commission: Double
    let grossProfitAfterCommission: Double

    // Residual amount (leftover after rounding quantity to whole number)
    let residualAmount: Double

    // MARK: - Builders
    /// Build using calculation service (preferred - uses proper fee calculations)
    static func build(
        trade: Trade,
        buyInvoice: Invoice?,
        sellInvoices: [Invoice],
        ownershipPercentage: Double,
        investorAllocatedAmount: Double,
        investmentCapitalAmount: Double,
        calculationService: any InvestorCollectionBillCalculationServiceProtocol,
        commissionCalculationService: any CommissionCalculationServiceProtocol,
        commissionRate: Double = CalculationConstants.FeeRates.traderCommissionRate
    ) throws -> InvestorInvestmentStatementItem {
        // Use calculation service for proper fee calculations
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

        // Use centralized commission calculation service
        let commission = commissionCalculationService.calculateCommission(
            grossProfit: output.grossProfit,
            rate: commissionRate
        )
        let grossProfitAfterCommission = commissionCalculationService.calculateNetProfitAfterCommission(
            grossProfit: output.grossProfit,
            rate: commissionRate
        )

        // Use the trade's ROI - same for all participants (trader and investors)
        let tradeROI = trade.displayROI

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
            tradeROI: tradeROI,
            commission: commission,
            grossProfitAfterCommission: grossProfitAfterCommission,
            residualAmount: output.residualAmount
        )
    }

    /// Simplified build using invoice data directly (legacy support)
    static func build(
        trade: Trade,
        buyInvoice: Invoice?,
        sellInvoices: [Invoice],
        ownershipPercentage: Double,
        investorAllocatedAmount: Double,
        commissionCalculationService: any CommissionCalculationServiceProtocol = CommissionCalculationService(),
        commissionRate: Double = CalculationConstants.FeeRates.traderCommissionRate
    ) -> InvestorInvestmentStatementItem {
        // Buy leg
        let buyPrice = trade.entryPrice
        let investorBuyQty = trade.totalQuantity * ownershipPercentage
        // ✅ FIX: Use invoice securities value (source of truth) instead of allocatedAmount
        // allocatedAmount is from trade creation and may not match actual invoice values
        // The invoice contains the actual securities value that was purchased
        let buyTotal = (buyInvoice?.securitiesTotal ?? 0.0) * ownershipPercentage
        let buyQty = investorBuyQty
        let roiInvestedAmount = investorBuyQty * buyPrice
        let buyFeeDetails = buildFeeDetails(
            from: buyInvoice,
            scale: ownershipPercentage
        )
        let buyFeesInvestor = buyFeeDetails.reduce(0) { $0 + $1.amount }

        // Sell leg - Use invoice securities values (source of truth) for consistency with buy side
        // Calculate total sell quantity and value from sell invoices
        let totalSellQtyFromInvoices = sellInvoices.reduce(0.0) { total, invoice in
            total + invoice.securitiesItems.reduce(0.0) { $0 + $1.quantity }
        }
        let totalSellValueFromInvoices = sellInvoices.reduce(0.0) { total, invoice in
            total + invoice.securitiesTotal
        }

        // Investor sells proportionally to trader sell percentage
        let sellPercentage = trade.totalQuantity > 0 ? (totalSellQtyFromInvoices / trade.totalQuantity) : 0.0
        let investorSellQty = investorBuyQty * sellPercentage

        // Calculate average sell price from invoices
        let sellAvgPrice = totalSellQtyFromInvoices > 0 ? totalSellValueFromInvoices / totalSellQtyFromInvoices : 0.0

        // Securities value before fees (scaled by ownership percentage)
        let investorSellValue = totalSellValueFromInvoices * ownershipPercentage

        // Fees from invoices (fees live on invoices, not orders)
        // Sell share is proportional to investor's sell value relative to total sell value from invoices
        let sellShare = totalSellValueFromInvoices > 0 ? (investorSellValue / totalSellValueFromInvoices) : ownershipPercentage
        let sellFeeDetails = buildFeeDetails(
            from: sellInvoices,
            scale: sellShare
        )
        let investorSellFees = sellFeeDetails.reduce(0) { $0 + $1.amount }

        // Profit before commission/taxes at investor level (matches collection bill display)
        let grossProfit = investorSellValue - investorSellFees - (buyTotal + buyFeesInvestor)

        // ROI profit uses pure securities values (aligned with trader ROI)
        let roiGrossProfit = investorSellValue - roiInvestedAmount

        let commission = commissionCalculationService.calculateCommission(
            grossProfit: grossProfit,
            rate: commissionRate
        )
        let grossProfitAfterCommission = commissionCalculationService.calculateNetProfitAfterCommission(
            grossProfit: grossProfit,
            rate: commissionRate
        )

        // Use the trade's ROI - same for all participants (trader and investors)
        let tradeROI = trade.displayROI

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
            tradeROI: tradeROI,
            commission: commission,
            grossProfitAfterCommission: grossProfitAfterCommission,
            residualAmount: 0.0  // Legacy method doesn't calculate residual
        )
    }

    private static func buildFeeDetails(
        from invoice: Invoice?,
        scale: Double
    ) -> [InvestorFeeDetail] {
        guard let invoice = invoice else { return [] }
        return buildFeeDetails(from: [invoice], scale: scale)
    }

    private static func buildFeeDetails(
        from invoices: [Invoice],
        scale: Double
    ) -> [InvestorFeeDetail] {
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
