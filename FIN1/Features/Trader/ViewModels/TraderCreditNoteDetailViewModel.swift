import Foundation
import SwiftUI

// MARK: - Credit Note Breakdown Item
/// Represents a single investor's commission breakdown in the credit note
struct CreditNoteBreakdownItem: Identifiable {
    let id: String
    /// Eindeutige Anzeige-Nummer des Investments (z. B. aus ID abgeleitet), für GoB-Zuordnung.
    let investmentNumber: String
    let investorName: String
    let grossProfit: Double
    let commissionRate: Double
    let commission: Double
}

// MARK: - Trader Credit Note Detail ViewModel
/// ViewModel for TraderCreditNoteDetailView
/// Handles data loading and business logic for credit note display
@MainActor
final class TraderCreditNoteDetailViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var breakdownItems: [CreditNoteBreakdownItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var tradeGrossProfit: Double = 0.0
    @Published var totalCommission: Double = 0.0
    @Published var tradeROI: Double = 0.0
    @Published var tradeDates: (entry: Date, exit: Date)?
    /// e.g. `Trade #001` — shown prominently on the Gutschrift.
    @Published var tradeReferenceLabel: String?
    /// WKN / underlying from the settled trade when available.
    @Published var tradeSecuritySummary: String?
    /// Für Document-Header (MVVM: View ruft keinen Service auf).
    @Published var accountHolderName: String = ""
    @Published var accountNumber: String = ""

    // MARK: - Dependencies
    private var appServices: AppServices?
    private var tradeId: String?
    private var creditNoteDocumentId: String?
    private var sourceDocument: Document?

    /// Persisted on the credit-note `Invoice` when issued (`traderCommissionRateSnapshot`).
    private var documentCommissionRateSnapshot: Double?

    /// After `loadBreakdown`, average `commission / grossProfit` from rows when no snapshot exists.
    private var displayRateFromBreakdown: Double?

    // MARK: - Initialization
    init() { }

    /// Configures the ViewModel with services and document (called from task). Berechnet accountHolderName/accountNumber aus document + UserService-Fallback.
    func configure(with services: AppServices, document: Document) {
        self.appServices = services
        self.sourceDocument = document
        self.creditNoteDocumentId = document.id
        self.tradeId = Self.resolveTradeId(document: document, services: services)
        self.refreshTradePresentation(document: document, services: services)
        self.displayRateFromBreakdown = nil
        self.documentCommissionRateSnapshot =
            document.traderCommissionRateSnapshot ?? document.invoiceData?.traderCommissionRateSnapshot

        if let invoiceData = document.invoiceData, !invoiceData.customerInfo.name.isEmpty {
            self.accountHolderName = invoiceData.customerInfo.name
        } else if let currentUser = services.userService.currentUser {
            self.accountHolderName = currentUser.displayName
        } else {
            self.accountHolderName = "Trader \(document.userId.prefix(8))"
        }

        if let invoiceData = document.invoiceData, !invoiceData.customerInfo.depotNumber.isEmpty {
            self.accountNumber = invoiceData.customerInfo.depotNumber
        } else if let currentUser = services.userService.currentUser {
            self.accountNumber = "DE\(String(format: "%020d", abs(currentUser.id.hashValue)))"
        } else {
            self.accountNumber = "DE\(String(format: "%020d", abs(document.userId.hashValue)))"
        }
    }

    // MARK: - Computed Properties
    var commissionRate: Double {
        if let documentCommissionRateSnapshot {
            return documentCommissionRateSnapshot
        }
        if let displayRateFromBreakdown {
            return displayRateFromBreakdown
        }
        return self.appServices?.configurationService.effectiveCommissionRate ?? 0.0
    }

    var formattedCommissionRate: String {
        let rate = self.commissionRate
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: NSNumber(value: rate)) ?? "0,00"
    }

    var formattedCommissionPercentage: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "de_DE")
        let percent = formatter.string(from: NSNumber(value: self.commissionRate * 100)) ?? "0"
        return "\(percent)%"
    }

    // MARK: - Data Loading
    func loadBreakdown() async {
        guard let appServices = appServices else {
            self.errorMessage = "Services not configured"
            return
        }

        self.isLoading = true
        self.errorMessage = nil

        guard let tradeId = tradeId else {
            self.errorMessage = "Keine Trade-ID verfügbar"
            self.isLoading = false
            return
        }

        // Get participations for this trade
        let participations = appServices.poolTradeParticipationService.getParticipations(forTradeId: tradeId)

        guard !participations.isEmpty else {
            await self.loadBreakdownFromBackendSettlement(tradeId: tradeId, services: appServices)
            if self.breakdownItems.isEmpty || self.totalCommission <= 0 {
                await self.applyInvoiceAndSettlementSummaryFallback(documentCommissionOnly: false)
            }
            self.isLoading = false
            return
        }

        // Get trade details for ROI, dates, and security line
        if let trade = appServices.tradingStateStore.completedTrades.first(where: { $0.id == tradeId }) {
            self.applyTradeContext(trade)
        }

        let rate = self.commissionRate
        let allInvestments = appServices.investmentService.investments
        let investmentIds = Array(Set(participations.map(\.investmentId)))

        if let api = appServices.settlementAPIService,
           let serverLines = await TradeInvestorCommissionBreakdownLoader.load(
               tradeId: tradeId,
               investmentIds: investmentIds,
               investments: allInvestments,
               settlementAPIService: api
           ) {
            self.applyCreditNoteBreakdown(serverLines, commissionRate: rate)
            if self.totalCommission <= 0 {
                await self.applyInvoiceAndSettlementSummaryFallback(documentCommissionOnly: true)
            }
            self.isLoading = false
            return
        }

        if appServices.configurationService.investorMonetaryServerOnly {
            await self.loadBreakdownFromBackendSettlement(tradeId: tradeId, services: appServices)
            if self.breakdownItems.isEmpty {
                await self.applyInvoiceAndSettlementSummaryFallback(documentCommissionOnly: true)
                if self.breakdownItems.isEmpty && self.totalCommission <= 0 {
                    self.errorMessage = "Gutschrift-Aufschlüsselung konnte nicht aus Server-Belegen geladen werden."
                }
            }
            self.isLoading = false
            return
        }

        let localLines = await TradeInvestorCommissionBreakdownLoader.loadLocalEstimate(
            tradeId: tradeId,
            investmentIds: investmentIds,
            investments: allInvestments,
            investorGrossProfitService: appServices.investorGrossProfitService,
            commissionCalculationService: appServices.commissionCalculationService,
            commissionRate: rate
        )
        self.applyCreditNoteBreakdown(localLines, commissionRate: rate)
        if self.breakdownItems.isEmpty {
            await self.loadBreakdownFromBackendSettlement(tradeId: tradeId, services: appServices)
        }
        if self.breakdownItems.isEmpty || self.totalCommission <= 0 {
            await self.applyInvoiceAndSettlementSummaryFallback(documentCommissionOnly: false)
        }
        self.isLoading = false
    }

    private static func resolveTradeId(document: Document, services: AppServices) -> String? {
        if let tradeId = document.tradeId, !tradeId.isEmpty { return tradeId }
        if let tradeNumber = document.resolvedTraderCreditNoteTradeNumber,
           let trade = services.tradingStateStore.completedTrades.first(where: { $0.tradeNumber == tradeNumber }) {
            return trade.id
        }
        if let tradeNumber = document.invoiceData?.tradeNumber,
           let trade = services.tradingStateStore.completedTrades.first(where: { $0.tradeNumber == tradeNumber }) {
            return trade.id
        }
        return nil
    }

    private func refreshTradePresentation(document: Document, services: AppServices) {
        if let label = document.traderCreditNoteTradeReferenceLabel {
            self.tradeReferenceLabel = label
        }

        let trade: Trade? = {
            if let tradeId, let found = services.tradingStateStore.completedTrades.first(where: { $0.id == tradeId }) {
                return found
            }
            if let number = document.resolvedTraderCreditNoteTradeNumber {
                return services.tradingStateStore.completedTrades.first(where: { $0.tradeNumber == number })
            }
            return nil
        }()

        if let trade {
            self.applyTradeContext(trade)
        }
    }

    private func applyTradeContext(_ trade: Trade) {
        self.tradeReferenceLabel = String(format: "Trade #%03d", trade.tradeNumber)
        let symbol = trade.symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = trade.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !symbol.isEmpty, !description.isEmpty, symbol.caseInsensitiveCompare(description) != .orderedSame {
            self.tradeSecuritySummary = "\(symbol) — \(description)"
        } else if !description.isEmpty {
            self.tradeSecuritySummary = description
        } else if !symbol.isEmpty {
            self.tradeSecuritySummary = symbol
        }
        self.tradeROI = trade.roi ?? self.tradeROI
        self.tradeDates = (trade.createdAt, trade.completedAt ?? trade.updatedAt)
    }

    private func applyInvoiceAndSettlementSummaryFallback(documentCommissionOnly: Bool) async {
        guard let services = appServices else { return }

        if let document = sourceDocument,
           let invoice = services.invoiceService.invoice(matching: document),
           let gross = TradesOverviewCommissionAmounts.grossCommission(from: invoice) {
            if self.totalCommission <= 0 { self.totalCommission = gross }
        }

        guard let tradeId, let api = services.settlementAPIService else { return }
        if let totals = await TradeCommissionSettlementBreakdownResolver.resolveSummaryTotals(
            tradeId: tradeId,
            creditNoteDocumentId: creditNoteDocumentId,
            settlementAPIService: api
        ) {
            if self.totalCommission <= 0 { self.totalCommission = totals.commission }
            if self.tradeGrossProfit <= 0 { self.tradeGrossProfit = totals.grossProfit }
        }

        if documentCommissionOnly { return }

        if let resolved = await TradeCommissionSettlementBreakdownResolver.resolve(
            tradeId: tradeId,
            creditNoteDocumentId: creditNoteDocumentId,
            investments: services.investmentService.investments,
            settlementAPIService: api
        ) {
            self.applyCreditNoteBreakdown(resolved.lines, commissionRate: self.commissionRate)
        }
    }

    private func applyCreditNoteBreakdown(_ lines: [TradeInvestorCommissionLine], commissionRate: Double) {
        let items = lines.map { line in
            CreditNoteBreakdownItem(
                id: line.investmentId,
                investmentNumber: line.investmentId.extractInvestmentNumber(),
                investorName: line.investorName,
                grossProfit: line.grossProfit,
                commissionRate: commissionRate,
                commission: line.commission
            )
        }
        self.breakdownItems = items
        self.tradeGrossProfit = lines.reduce(0) { $0 + $1.grossProfit }
        self.totalCommission = lines.reduce(0) { $0 + $1.commission }
        self.displayRateFromBreakdown = Self.impliedCommissionRate(from: items)
    }

    private func loadBreakdownFromBackendSettlement(tradeId: String, services: AppServices) async {
        guard let settlementAPI = services.settlementAPIService else {
            self.breakdownItems = []
            return
        }

        if let trade = services.tradingStateStore.completedTrades.first(where: { $0.id == tradeId }) {
            self.applyTradeContext(trade)
        }

        guard let resolved = await TradeCommissionSettlementBreakdownResolver.resolve(
            tradeId: tradeId,
            creditNoteDocumentId: creditNoteDocumentId,
            investments: services.investmentService.investments,
            settlementAPIService: settlementAPI
        ) else {
            self.errorMessage = "Gutschrift-Details konnten nicht aus dem Settlement geladen werden."
            self.breakdownItems = []
            return
        }

        self.errorMessage = nil
        self.applyCreditNoteBreakdown(resolved.lines, commissionRate: self.commissionRate)
        if self.tradeGrossProfit <= 0 { self.tradeGrossProfit = resolved.totalGrossProfit }
        if self.totalCommission <= 0 { self.totalCommission = resolved.totalCommission }
    }

    /// Aligns header percentage with per-row amounts (`commission = gross × rate` from `CommissionCalculationService`).
    private static func impliedCommissionRate(from items: [CreditNoteBreakdownItem]) -> Double? {
        let candidates = items.filter { $0.grossProfit > 0.000_001 }
        guard !candidates.isEmpty else { return nil }
        let ratios = candidates.map { $0.commission / $0.grossProfit }
        let average = ratios.reduce(0, +) / Double(ratios.count)
        guard average.isFinite, average >= 0 else { return nil }
        return average
    }
}
