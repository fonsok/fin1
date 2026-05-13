import Combine
import SwiftUI

// MARK: - Trade Details View Model

@MainActor
final class TradeDetailsViewModel: ObservableObject {
    let trade: TradeOverviewItem
    private var invoiceService: (any InvoiceServiceProtocol)?
    private var tradeService: (any TradeLifecycleServiceProtocol)?
    private let calculationService = TradeCalculationService()
    private let calculationGuardService: CalculationGuardService

    // Full Trade object for accessing multiple sell orders
    @Published var fullTrade: Trade?

    // UI State
    @Published var showCollectionBill = false
    @Published var showBuyInvoice = false
    @Published var showSellInvoice = false
    @Published var showCreditNote = false
    @Published var selectedSellInvoice: Invoice?

    // Calculation breakdown
    @Published var calculationBreakdown: TradeCalculationService.TransactionBreakdown?

    // Derived display fields for the details table
    var tradeNumberText: String { "\(self.trade.tradeNumber)" }
    var gvCurrencyText: String {
        self.trade.profitLoss.formatted(.currency(code: "EUR"))
    }
    var gvPercentText: String {
        self.trade.returnPercentage.formattedAsROIPercentage() + " "
    }

    // MARK: - ROI Calculation Components

    /// Numerator for ROI calculation (profit/loss amount)
    var roiNumerator: Double {
        // Use netCashFlow if invoices are loaded, otherwise use trade.profitLoss
        if self.buyInvoice != nil || !self.sellInvoices.isEmpty {
            return self.netCashFlow
        }
        return self.trade.profitLoss
    }

    /// Denominator for ROI calculation (investment cost)
    var roiDenominator: Double {
        // Use actual buy amount from invoices if available
        if self.buyInvoice != nil || !self.sellInvoices.isEmpty {
            return abs(self.buyOrderCashFlow)
        }
        // Otherwise, calculate from percentage: Investment = Profit / (ROI / 100)
        // ROI is stored as percentage (e.g., 99 for 99%), so we divide by 100
        guard self.trade.returnPercentage != 0 else { return 0 }
        return abs(self.trade.profitLoss / (self.trade.returnPercentage / 100))
    }

    /// Formatted ROI numerator (profit/loss)
    var formattedRoiNumerator: String {
        self.roiNumerator.formatted(.currency(code: "EUR"))
    }

    /// Formatted ROI denominator (investment cost)
    var formattedRoiDenominator: String {
        self.roiDenominator.formatted(.currency(code: "EUR"))
    }

    /// ROI calculation label showing "ROI (Profit: value1 / Investment: value2)"
    var roiCalculationLabel: String {
        "ROI (Profit: \(self.formattedRoiNumerator) / Investment: \(self.formattedRoiDenominator))"
    }

    var provisionText: String {
        self.trade.commission == 0 ? "-" : self.trade.commission.formatted(.currency(code: "EUR"))
    }

    var startDateText: String {
        self.trade.startDate.formatted(date: .abbreviated, time: .omitted)
    }

    var endDateText: String {
        self.trade.endDate.formatted(date: .abbreviated, time: .omitted)
    }

    var statusText: String {
        self.trade.statusText
    }

    // Invoices related
    @Published var buyInvoice: Invoice?
    @Published var sellInvoices: [Invoice] = [] // Multiple sell invoices for partial sells
    @Published var creditNoteInvoice: Invoice?

    var feesAmount: Double {
        let allInvoices = [buyInvoice].compactMap { $0 } + self.sellInvoices
        return allInvoices.reduce(0) { $0 + $1.feesTotal }
    }

    var taxesAmount: Double {
        let allInvoices = [buyInvoice].compactMap { $0 } + self.sellInvoices
        return allInvoices.reduce(0) { $0 + $1.taxTotal }
    }

    var feesText: String { self.feesAmount == 0 ? "-" : self.feesAmount.formatted(.currency(code: "EUR")) }
    var taxesText: String { self.taxesAmount == 0 ? "-" : self.taxesAmount.formatted(.currency(code: "EUR")) }

    // Grouped fee and tax items with summed amounts
    var groupedFeeItems: [(type: InvoiceItemType, amount: Double)] {
        let allInvoices = [buyInvoice].compactMap { $0 } + self.sellInvoices
        let items = allInvoices.flatMap { invoice in invoice.items }
        let feeItems = items.filter { item in
            item.itemType == .orderFee || item.itemType == .exchangeFee || item.itemType == .foreignCosts
        }

        // Group by item type and sum amounts
        let grouped = Dictionary(grouping: feeItems, by: { $0.itemType })
        return grouped.map { (type, items) in
            let totalAmount = items.reduce(0) { $0 + abs($1.totalAmount) }
            return (type: type, amount: totalAmount)
        }.sorted { $0.type.rawValue < $1.type.rawValue }
    }

    var groupedTaxItems: [(type: InvoiceItemType, amount: Double)] {
        let allInvoices = [buyInvoice].compactMap { $0 } + self.sellInvoices
        let taxItems = allInvoices.allTaxItems

        // Group by item type and sum amounts
        let grouped = Dictionary(grouping: taxItems, by: { $0.itemType })
        return grouped.map { (type, items) in
            let totalAmount = items.reduce(0) { $0 + $1.absoluteAmount }
            return (type: type, amount: totalAmount)
        }.sorted { $0.type.rawValue < $1.type.rawValue }
    }

    // MARK: - Tax Breakdown Calculations

    /// Calculates the capital gains tax (Kapitalertragsteuer) at 25%
    var capitalGainsTax: Double {
        // Use the actual cash flow profit (from invoices) for consistent tax calculations
        let grossProfit = self.netCashFlow
        return InvoiceTaxCalculator.calculateCapitalGainsTax(for: grossProfit)
    }

    /// Calculates the solidarity surcharge at 5.5% of capital gains tax
    var solidaritySurcharge: Double {
        return InvoiceTaxCalculator.calculateSolidaritySurcharge(for: self.capitalGainsTax)
    }

    /// Calculates the church tax (Kirchensteuer) at 8% of capital gains tax
    var churchTax: Double {
        return InvoiceTaxCalculator.calculateChurchTax(for: self.capitalGainsTax)
    }

    /// Total tax amount
    var totalTaxAmount: Double {
        // Use the actual cash flow profit (from invoices) for consistent tax calculations
        let grossProfit = self.netCashFlow
        return self.calculationGuardService.guardTaxCalculation(profit: grossProfit)
    }

    /// Formatted tax amounts
    var formattedCapitalGainsTax: String {
        self.capitalGainsTax.formatted(.currency(code: "EUR"))
    }

    var formattedSolidaritySurcharge: String {
        self.solidaritySurcharge.formatted(.currency(code: "EUR"))
    }

    var formattedChurchTax: String {
        self.churchTax.formatted(.currency(code: "EUR"))
    }

    var formattedTotalTaxAmount: String {
        self.totalTaxAmount.formatted(.currency(code: "EUR"))
    }

    // MARK: - Net Profit/Loss Calculation

    /// Calculates the net amount credited to user's cash balance (profit minus taxes)
    var netCreditAmount: Double {
        // Use the actual cash flow profit (from invoices) instead of trade.profitLoss
        // This ensures fees are properly included in the calculation
        let grossProfit = self.netCashFlow
        return InvoiceTaxCalculator.calculateNetAmountAfterTaxes(for: grossProfit)
    }

    /// Formatted net profit/loss amount
    var formattedNetCreditAmount: String {
        self.netCreditAmount.formatted(.currency(code: "EUR"))
    }

    /// Label for net profit/loss based on amount
    var netProfitLossLabel: String {
        return self.netCreditAmount >= 0 ? "Gewinn (netto)" : "Verlust (netto)"
    }

    // MARK: - Cash Flow Calculations

    /// Calculates the total amount spent on buy orders (negative cash flow)
    var buyOrderCashFlow: Double {
        let allInvoices = [buyInvoice].compactMap { $0 } + self.sellInvoices
        let buyInvoices = allInvoices.filter { $0.transactionType == .buy }
        return -buyInvoices.reduce(0) { $0 + $1.nonTaxTotal } // Negative because money goes out
    }

    /// Calculates the total amount received from sell orders (positive cash flow)
    var sellOrderCashFlow: Double {
        let allInvoices = [buyInvoice].compactMap { $0 } + sellInvoices
        let sellInvoices = allInvoices.filter { $0.transactionType == .sell }
        return sellInvoices.reduce(0) { $0 + $1.nonTaxTotal } // Positive because money comes in
    }

    /// Net cash flow from the trade (before taxes)
    var netCashFlow: Double {
        return self.buyOrderCashFlow + self.sellOrderCashFlow
    }

    /// Formatted cash flow amounts
    var formattedBuyOrderCashFlow: String {
        self.buyOrderCashFlow.formatted(.currency(code: "EUR"))
    }

    var formattedSellOrderCashFlow: String {
        self.sellOrderCashFlow.formatted(.currency(code: "EUR"))
    }

    var formattedNetCashFlow: String {
        self.netCashFlow.formatted(.currency(code: "EUR"))
    }

    // MARK: - Initialization

    init(trade: TradeOverviewItem, calculationGuardService: CalculationGuardService = CalculationGuardService.shared) {
        self.trade = trade
        self.calculationGuardService = calculationGuardService
    }

    // MARK: - Service Attachment

    func attach(invoiceService: any InvoiceServiceProtocol, tradeService: any TradeLifecycleServiceProtocol) {
        print("📌 TradeDetailsViewModel.attach - Trade #\(self.trade.tradeNumber)")
        self.invoiceService = invoiceService
        self.tradeService = tradeService
        self.loadFullTrade()
        self.loadInvoices()
    }

    // MARK: - Private Methods

    private func loadFullTrade() {
        guard let service = tradeService, let tradeId = trade.tradeId else {
            print("❌ No trade service or trade ID")
            return
        }

        // Find the full Trade object from the trade service
        let completedTrades = service.completedTrades
        fullTrade = completedTrades.first { $0.id == tradeId }

        if let fullTrade = fullTrade {
            print("🔍 Loaded full trade with \(fullTrade.sellOrders.count) sell orders")
        } else {
            print("❌ Could not find full trade for ID: \(tradeId)")
        }
    }

    private func loadInvoices() {
        guard let service = invoiceService, let tradeId = trade.tradeId else {
            print("❌ No invoice service or trade ID")
            return
        }

        // Load all invoices for this trade using the correct method
        let allInvoices = service.getInvoicesForTrade(tradeId)

        // Separate buy and sell invoices
        self.buyInvoice = allInvoices.first { $0.transactionType == .buy }
        self.sellInvoices = allInvoices.filter { $0.transactionType == .sell }
        self.creditNoteInvoice = allInvoices.first { $0.type == .creditNote }

        print(
            "📄 Loaded \(allInvoices.count) invoices: \(self.buyInvoice != nil ? "1 buy" : "0 buy"), \(self.sellInvoices.count) sell, \(self.creditNoteInvoice != nil ? "1 credit" : "0 credit")"
        )

        // Calculate detailed breakdown
        self.calculateDetailedBreakdown()
    }

    private func calculateDetailedBreakdown() {
        guard let fullTrade = fullTrade else {
            print("❌ No full trade available for calculation")
            return
        }

        self.calculationBreakdown = self.calculationService.calculateTradeBreakdown(
            for: fullTrade,
            buyInvoice: self.buyInvoice,
            sellInvoices: self.sellInvoices
        )

        print("🧮 Calculated detailed breakdown for trade #\(self.trade.tradeNumber)")
    }
}
