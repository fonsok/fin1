import SwiftUI

// MARK: - Trades Overview Models

/// Represents a single item in the trades overview list
struct TradeOverviewItem: Identifiable {
    let id = UUID()
    let tradeId: String? // Actual trade ID for linking with invoices
    let tradeNumber: Int
    let tradeNumberYear: Int?
    let startDate: Date
    let endDate: Date
    let profitLoss: Double // Net profit (after fees)
    let returnPercentage: Double
    let commission: Double
    /// True while backend settlement / credit note is still loading (show placeholder, not "-").
    let isCommissionPending: Bool
    let isActive: Bool
    let statusText: String
    let statusDetail: String
    let onDetailsTapped: () -> Void

    // Additional fields for profit breakdown info
    let grossProfit: Double // Gross profit (before fees)
    let totalFees: Double // Total fees for the trade

    init(
        tradeId: String?,
        tradeNumber: Int,
        tradeNumberYear: Int? = nil,
        startDate: Date,
        endDate: Date,
        profitLoss: Double,
        returnPercentage: Double,
        commission: Double,
        isCommissionPending: Bool,
        isActive: Bool,
        statusText: String,
        statusDetail: String,
        onDetailsTapped: @escaping () -> Void,
        grossProfit: Double,
        totalFees: Double
    ) {
        self.tradeId = tradeId
        self.tradeNumber = tradeNumber
        self.tradeNumberYear = tradeNumberYear
        self.startDate = startDate
        self.endDate = endDate
        self.profitLoss = profitLoss
        self.returnPercentage = returnPercentage
        self.commission = commission
        self.isCommissionPending = isCommissionPending
        self.isActive = isActive
        self.statusText = statusText
        self.statusDetail = statusDetail
        self.onDetailsTapped = onDetailsTapped
        self.grossProfit = grossProfit
        self.totalFees = totalFees
    }

    var resolvedTradeNumberYear: Int {
        self.tradeNumberYear ?? TradeNumberFormatting.calendarYear(for: self.startDate)
    }

    var formattedTradeNumber: String {
        TradeNumberFormatting.display(number: self.tradeNumber, year: self.resolvedTradeNumberYear)
    }

    /// User-facing label for lists and detail headers (never raw integer).
    var displayTradeNumber: String {
        let formatted = self.formattedTradeNumber
        return formatted.isEmpty ? "—" : formatted
    }

    var backgroundColor: Color {
        // Alternate row colors for better readability
        return self.tradeNumber % 2 == 0 ? AppTheme.sectionBackground : AppTheme.sectionBackground.opacity(0.8)
    }
}

/// Time period options for filtering trades
enum TradeTimePeriod: CaseIterable {
    case last7Days
    case last30Days
    case last90Days
    case lastYear
    case allTime

    var displayName: String {
        switch self {
        case .last7Days: return "Letzte 7 Tage"
        case .last30Days: return "Letzte 30 Tage"
        case .last90Days: return "Letzte 90 Tage"
        case .lastYear: return "Letztes Jahr"
        case .allTime: return "Alle"
        }
    }
}
