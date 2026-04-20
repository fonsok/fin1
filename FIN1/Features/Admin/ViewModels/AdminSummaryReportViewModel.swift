import Foundation
import Combine

// MARK: - Admin Summary Report ViewModel
/// Aggregates completed investments and trades from account statements (source of truth)
@MainActor
final class AdminSummaryReportViewModel: ObservableObject {

    // MARK: - Published State
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var selectedDateRange: DateRangeFilter = .allTime
    @Published var selectedInvestorId: String? = nil
    @Published var selectedTraderId: String? = nil

    // Summary Data
    @Published private(set) var summary: AdminSummaryReport = AdminSummaryReport.empty

    // MARK: - Dependencies
    private let investmentService: any InvestmentServiceProtocol
    private let tradeLifecycleService: any TradeLifecycleServiceProtocol
    private let investorCashBalanceService: any InvestorCashBalanceServiceProtocol
    private let invoiceService: any InvoiceServiceProtocol
    private let poolTradeParticipationService: any PoolTradeParticipationServiceProtocol
    private let userService: any UserServiceProtocol
    private let configurationService: any ConfigurationServiceProtocol
    private let settlementAPIService: (any SettlementAPIServiceProtocol)?

    // MARK: - Initialization

    init(services: AppServices) {
        self.investmentService = services.investmentService
        self.tradeLifecycleService = services.tradeLifecycleService
        self.investorCashBalanceService = services.investorCashBalanceService
        self.invoiceService = services.invoiceService
        self.poolTradeParticipationService = services.poolTradeParticipationService
        self.userService = services.userService
        self.configurationService = services.configurationService
        self.settlementAPIService = services.settlementAPIService
    }

    // MARK: - Public Methods

    func load() {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        Task {
            let report = await buildSummaryReport()
            summary = report
            isLoading = false
        }
    }

    func refresh() {
        load()
    }

    // MARK: - Private Methods

    private func buildSummaryReport() async -> AdminSummaryReport {
        // Get all investments
        let allInvestments = investmentService.investments

        // Filter completed investments
        let completedInvestments = allInvestments.filter { investment in
            investment.status == .completed || investment.status == .cancelled ||
            (investment.status == .active && investment.reservationStatus == .completed)
        }

        // Apply filters
        let filteredInvestments = applyInvestmentFilters(completedInvestments)

        // Get all completed trades
        let allTrades = tradeLifecycleService.completedTrades
        let filteredTrades = applyTradeFilters(allTrades)

        // Build investment summaries
        var investmentDetails: [AdminInvestmentSummary] = []
        var totalInvestedAmount: Double = 0
        var totalCurrentValue: Double = 0
        var totalGrossProfit: Double = 0
        var totalCommission: Double = 0

        let commissionRate = configurationService.effectiveCommissionRate

        for investment in filteredInvestments {
            // Get statement summary (source of truth)
            let statementSummary = InvestorInvestmentStatementAggregator.summarizeInvestment(
                investmentId: investment.id,
                poolTradeParticipationService: poolTradeParticipationService,
                tradeLifecycleService: tradeLifecycleService,
                invoiceService: invoiceService,
                investmentService: investmentService,
                calculationService: InvestorCollectionBillCalculationService(),
                commissionCalculationService: nil,  // Use default
                investment: investment,
                commissionRate: commissionRate
            )

            let grossProfit = statementSummary?.statementGrossProfit ?? 0
            let commission = statementSummary?.statementCommission ?? 0

            totalInvestedAmount += investment.amount
            totalCurrentValue += investment.currentValue
            totalGrossProfit += grossProfit
            totalCommission += commission

            // Get trade numbers
            let participations = poolTradeParticipationService.getParticipations(forInvestmentId: investment.id)
            let tradeNumbers = participations.compactMap { participation -> Int? in
                guard let trade = filteredTrades.first(where: { $0.id == participation.tradeId }) else {
                    return nil
                }
                return trade.tradeNumber
            }.sorted()

            investmentDetails.append(AdminInvestmentSummary(
                investmentId: investment.id,
                investmentNumber: investment.id.extractInvestmentNumber(),
                investorId: investment.investorId,
                investorName: investment.investorName,
                traderId: investment.traderId,
                traderName: investment.traderName,
                amount: investment.amount,
                currentValue: investment.currentValue,
                grossProfit: grossProfit,
                returnPercentage: await ServerCalculatedReturnResolver.resolveReturnPercentage(
                    investmentId: investment.id,
                    settlementAPIService: settlementAPIService
                ),
                commission: commission,
                tradeNumbers: tradeNumbers,
                completedAt: investment.completedAt ?? investment.updatedAt,
                status: investment.status
            ))
        }

        // Build trade summaries
        var tradeDetails: [AdminTradeSummary] = []
        var totalTradeVolume: Double = 0
        var totalTradeProfit: Double = 0

        for trade in filteredTrades {
            let allInvoices = invoiceService.getInvoicesForTrade(trade.id)
            let buyInvoice = allInvoices.first { $0.transactionType == .buy }
            let sellInvoices = allInvoices.filter { $0.transactionType == .sell }

            let buyAmount = buyInvoice?.totalAmount ?? 0
            let sellAmount = sellInvoices.reduce(0) { $0 + $1.totalAmount }
            // Use displayProfit as single source of truth for profit (handles optional finalPnL)
            let tradeProfit = trade.displayProfit

            totalTradeVolume += buyAmount
            totalTradeProfit += tradeProfit

            // Get investor participations
            let participations = poolTradeParticipationService.getParticipations(forTradeId: trade.id)
            let investorIds = Set(participations.map { $0.investmentId })
                .compactMap { investmentId -> String? in
                    guard let investment = allInvestments.first(where: { $0.id == investmentId }) else {
                        return nil
                    }
                    return investment.investorId
                }

            tradeDetails.append(AdminTradeSummary(
                tradeId: trade.id,
                tradeNumber: trade.tradeNumber,
                symbol: trade.symbol,
                traderId: trade.traderId,
                buyAmount: buyAmount,
                sellAmount: sellAmount,
                profit: tradeProfit,
                investorIds: Array(investorIds),
                completedAt: trade.completedAt ?? trade.updatedAt
            ))
        }

        // Sort by completion date (newest first)
        investmentDetails.sort { $0.completedAt > $1.completedAt }
        tradeDetails.sort { $0.completedAt > $1.completedAt }

        return AdminSummaryReport(
            totalInvestments: filteredInvestments.count,
            totalTrades: filteredTrades.count,
            totalInvestedAmount: totalInvestedAmount,
            totalCurrentValue: totalCurrentValue,
            totalGrossProfit: totalGrossProfit,
            totalCommission: totalCommission,
            totalTradeVolume: totalTradeVolume,
            totalTradeProfit: totalTradeProfit,
            investments: investmentDetails,
            trades: tradeDetails,
            generatedAt: Date()
        )
    }

    private func applyInvestmentFilters(_ investments: [Investment]) -> [Investment] {
        var filtered = investments

        // Date range filter
        if let dateRange = selectedDateRange.dateRange {
            filtered = filtered.filter { investment in
                let completionDate = investment.completedAt ?? investment.updatedAt
                return completionDate >= dateRange.start && completionDate <= dateRange.end
            }
        }

        // Investor filter
        if let investorId = selectedInvestorId {
            filtered = filtered.filter { $0.investorId == investorId }
        }

        // Trader filter
        if let traderId = selectedTraderId {
            filtered = filtered.filter { $0.traderId == traderId }
        }

        return filtered
    }

    private func applyTradeFilters(_ trades: [Trade]) -> [Trade] {
        var filtered = trades

        // Date range filter
        if let dateRange = selectedDateRange.dateRange {
            filtered = filtered.filter { trade in
                let completionDate = trade.completedAt ?? trade.updatedAt
                return completionDate >= dateRange.start && completionDate <= dateRange.end
            }
        }

        // Trader filter
        if let traderId = selectedTraderId {
            filtered = filtered.filter { $0.traderId == traderId }
        }

        return filtered
    }
}

// MARK: - Date Range Filter

enum DateRangeFilter: String, CaseIterable, Identifiable {
    case allTime
    case lastMonth
    case lastThreeMonths
    case lastYear
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .allTime: return "All Time"
        case .lastMonth: return "Last 30 Days"
        case .lastThreeMonths: return "Last 3 Months"
        case .lastYear: return "Last Year"
        case .custom: return "Custom Range"
        }
    }

    var dateRange: (start: Date, end: Date)? {
        let calendar = Calendar.current
        let now = Date()
        let end = calendar.startOfDay(for: now)

        switch self {
        case .allTime:
            return nil
        case .lastMonth:
            guard let start = calendar.date(byAdding: .day, value: -30, to: end) else { return nil }
            return (start, end)
        case .lastThreeMonths:
            guard let start = calendar.date(byAdding: .month, value: -3, to: end) else { return nil }
            return (start, end)
        case .lastYear:
            guard let start = calendar.date(byAdding: .year, value: -1, to: end) else { return nil }
            return (start, end)
        case .custom:
            return nil // Custom range handled separately
        }
    }
}

