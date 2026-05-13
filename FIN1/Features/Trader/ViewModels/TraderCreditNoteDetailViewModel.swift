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
    /// Für Document-Header (MVVM: View ruft keinen Service auf).
    @Published var accountHolderName: String = ""
    @Published var accountNumber: String = ""

    // MARK: - Dependencies
    private var appServices: AppServices?
    private var tradeId: String?

    /// Persisted on the credit-note `Invoice` when issued (`traderCommissionRateSnapshot`).
    private var documentCommissionRateSnapshot: Double?

    /// After `loadBreakdown`, average `commission / grossProfit` from rows when no snapshot exists.
    private var displayRateFromBreakdown: Double?

    // MARK: - Initialization
    init() { }

    /// Configures the ViewModel with services and document (called from task). Berechnet accountHolderName/accountNumber aus document + UserService-Fallback.
    func configure(with services: AppServices, document: Document) {
        self.appServices = services
        self.tradeId = document.tradeId
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
            return
        }

        // Get trade details for ROI and dates
        if let trade = appServices.tradingStateStore.completedTrades.first(where: { $0.id == tradeId }) {
            self.tradeROI = trade.roi ?? 0.0
            self.tradeDates = (trade.createdAt, trade.completedAt ?? Date())
        }

        // Get commission rate
        let rate = self.commissionRate

        // Get all investments
        let allInvestments = appServices.investmentService.investments

        // Group participations by investment
        let participationsByInvestment = Dictionary(grouping: participations) { $0.investmentId }

        var items: [CreditNoteBreakdownItem] = []
        var totalProfit: Double = 0.0
        var totalComm: Double = 0.0

        // Calculate commission for each investor
        for (investmentId, _) in participationsByInvestment {
            guard let investment = allInvestments.first(where: { $0.id == investmentId }) else {
                continue
            }

            do {
                let investorGrossProfit = try await appServices.investorGrossProfitService.getGrossProfit(
                    for: investmentId,
                    tradeId: tradeId
                )

                let investorCommission = try await appServices.commissionCalculationService.calculateCommissionForInvestor(
                    investmentId: investmentId,
                    tradeId: tradeId,
                    commissionRate: rate
                )

                let investorName = investment.investorName
                let investmentNumber = investmentId.extractInvestmentNumber()

                items.append(CreditNoteBreakdownItem(
                    id: investmentId,
                    investmentNumber: investmentNumber,
                    investorName: investorName,
                    grossProfit: investorGrossProfit,
                    commissionRate: rate,
                    commission: investorCommission
                ))

                totalProfit += investorGrossProfit
                totalComm += investorCommission
            } catch {
                print("⚠️ TraderCreditNoteDetailViewModel: Error calculating for investment \(investmentId): \(error)")
                continue
            }
        }

        self.breakdownItems = items
        self.tradeGrossProfit = totalProfit
        self.totalCommission = totalComm
        self.displayRateFromBreakdown = Self.impliedCommissionRate(from: items)
        self.isLoading = false
    }

    private func loadBreakdownFromBackendSettlement(tradeId: String, services: AppServices) async {
        guard let settlementAPI = services.settlementAPIService else {
            self.breakdownItems = []
            self.tradeGrossProfit = 0
            self.totalCommission = 0
            self.isLoading = false
            return
        }

        do {
            let settlement = try await settlementAPI.fetchTradeSettlement(tradeId: tradeId)
            let allInvestments = services.investmentService.investments
            let grouped = Dictionary(grouping: settlement.commissions) { $0.investmentId ?? $0.objectId }

            var items: [CreditNoteBreakdownItem] = []
            var totalGross: Double = 0
            var totalComm: Double = 0

            for (investmentId, rows) in grouped {
                let commission = rows.compactMap { $0.commissionAmount }.reduce(0, +)
                guard commission > 0 else { continue }
                let explicitGross = rows.compactMap { $0.investorGrossProfit }.reduce(0, +)
                let rate = rows.compactMap { $0.commissionRate }.first ?? self.commissionRate
                let gross = explicitGross > 0 ? explicitGross : (rate > 0 ? commission / rate : 0)

                let investment = allInvestments.first { $0.id == investmentId }
                let investorName = investment?.investorName
                    ?? self.displayName(from: rows.first?.investorId)
                    ?? "Investor"
                let investmentNumber = investment?.investmentNumber ?? investmentId.extractInvestmentNumber()

                items.append(CreditNoteBreakdownItem(
                    id: investmentId,
                    investmentNumber: investmentNumber,
                    investorName: investorName,
                    grossProfit: gross,
                    commissionRate: rate,
                    commission: commission
                ))
                totalGross += gross
                totalComm += commission
            }

            self.breakdownItems = items.sorted { $0.investorName < $1.investorName }
            self.tradeGrossProfit = totalGross
            self.totalCommission = totalComm
            self.displayRateFromBreakdown = Self.impliedCommissionRate(from: items)
            self.isLoading = false
        } catch {
            self.errorMessage = "Gutschrift-Details konnten nicht aus dem Settlement geladen werden."
            self.breakdownItems = []
            self.tradeGrossProfit = 0
            self.totalCommission = 0
            self.isLoading = false
        }
    }

    private func displayName(from investorId: String?) -> String? {
        guard let investorId, investorId.hasPrefix("user:") else { return nil }
        let raw = String(investorId.dropFirst("user:".count))
        return raw.split(separator: "@").first.map(String.init)
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
