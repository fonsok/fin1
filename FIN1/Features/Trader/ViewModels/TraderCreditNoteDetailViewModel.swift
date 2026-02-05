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

    // MARK: - Initialization
    init() { }

    /// Configures the ViewModel with services and document (called from task). Berechnet accountHolderName/accountNumber aus document + UserService-Fallback.
    func configure(with services: AppServices, document: Document) {
        self.appServices = services
        self.tradeId = document.tradeId

        if let invoiceData = document.invoiceData, !invoiceData.customerInfo.name.isEmpty {
            accountHolderName = invoiceData.customerInfo.name
        } else if let currentUser = services.userService.currentUser {
            accountHolderName = currentUser.displayName
        } else {
            accountHolderName = "Trader \(document.userId.prefix(8))"
        }

        if let invoiceData = document.invoiceData, !invoiceData.customerInfo.depotNumber.isEmpty {
            accountNumber = invoiceData.customerInfo.depotNumber
        } else if let currentUser = services.userService.currentUser {
            accountNumber = "DE\(String(format: "%020d", abs(currentUser.id.hashValue)))"
        } else {
            accountNumber = "DE\(String(format: "%020d", abs(document.userId.hashValue)))"
        }
    }

    // MARK: - Computed Properties
    var commissionRate: Double {
        appServices?.configurationService.traderCommissionRate ?? 0.05
    }

    var formattedCommissionRate: String {
        let rate = commissionRate
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: NSNumber(value: rate)) ?? "0,05"
    }

    var formattedCommissionPercentage: String {
        "\(Int(commissionRate * 100))%"
    }

    // MARK: - Data Loading
    func loadBreakdown() async {
        guard let appServices = appServices else {
            errorMessage = "Services not configured"
            return
        }

        isLoading = true
        errorMessage = nil

        guard let tradeId = tradeId else {
            errorMessage = "Keine Trade-ID verfügbar"
            isLoading = false
            return
        }

        // Get participations for this trade
        let participations = appServices.poolTradeParticipationService.getParticipations(forTradeId: tradeId)

        guard !participations.isEmpty else {
            breakdownItems = []
            isLoading = false
            return
        }

        // Get trade details for ROI and dates
        if let trade = appServices.tradingStateStore.completedTrades.first(where: { $0.id == tradeId }) {
            self.tradeROI = trade.roi ?? 0.0
            self.tradeDates = (trade.createdAt, trade.completedAt ?? Date())
        }

        // Get commission rate
        let rate = commissionRate

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

        breakdownItems = items
        tradeGrossProfit = totalProfit
        totalCommission = totalComm
        isLoading = false
    }

}
