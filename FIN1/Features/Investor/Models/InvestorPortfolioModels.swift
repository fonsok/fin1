import SwiftUI
import Foundation

// MARK: - Investor Portfolio Models

struct Portfolio {
    var totalValue: Double = 0
    var totalInvested: Double = 0
    var totalUnrealizedPnL: Double = 0
    var totalInvestments: Int = 0
    var activeInvestments: Int = 0
    var averagePerformance: Double = 0

    var isPositivePnL: Bool {
        totalUnrealizedPnL >= 0
    }

    var totalReturnPercentage: Double {
        guard totalInvested > 0 else { return 0.0 }
        return (totalUnrealizedPnL / totalInvested) * 100
    }
}

struct PerformanceData: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let change: Double
    let changePercentage: Double

    var isPositive: Bool {
        change >= 0
    }

    var formattedValue: String {
        value.formattedAsLocalizedCurrency()
    }

    var formattedChange: String {
        let prefix = isPositive ? "+" : ""
        return "\(prefix)\(change.formattedAsLocalizedCurrency())"
    }

    var formattedChangePercentage: String {
        let prefix = isPositive ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", changePercentage))%"
    }
}

enum Timeframe: String, CaseIterable {
    case week = "1W"
    case month = "1M"
    case quarter = "3M"
    case year = "1Y"
    case all = "ALL"

    var displayName: String {
        rawValue
    }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        case .all: return 0 // All available data
        }
    }
}

enum SortOption: String, CaseIterable {
    case date = "Date"
    case amount = "Amount"
    case performance = "Performance"
    case value = "Current Value"

    var displayName: String {
        rawValue
    }
}

enum InvestmentSortOption: String, CaseIterable {
    case date = "Date"
    case amount = "Amount"
    case performance = "Performance"
    case status = "Status"

    var displayName: String {
        rawValue
    }
}

// MARK: - Investment Row Model for Table Display

struct InvestmentRow: Identifiable {
    let id: String
    let investmentId: String
    let investmentNumber: String
    let traderName: String
    let sequenceNumber: Int
    let status: InvestmentReservationStatusDisplay
    let amount: Double
    let profit: Double?
    let returnPercentage: Double?
    let reservation: InvestmentReservation
    let investment: Investment
    /// Belegnummer Verrechnung (Investor Collection Bill); von ViewModel aus Services befüllt (MVVM).
    let docNumber: String?
    /// Rechnungsnummer Service-Charge; von ViewModel aus Services befüllt (MVVM).
    let invoiceNumber: String?

    var statusDisplayText: String {
        // Each investment shows its own status, not a count
        switch status {
        case .completed:
            // Status 3: Completed
            return "compl."
        case .active:
            // Status 2: Active
            return "active"
        case .reserved:
            // Status 1: Reserved - no text, just trash icon
            return ""
        }
    }

    var statusCount: Int {
        // Since each investment is a first-class entity, we just return 1
        // If we need to count investments in a batch, we'd need to query by batchId
        return 1
    }

    var isDeletable: Bool {
        // Only status 1 (reserved) can be deleted
        // Status 2 (active) and Status 3 (completed) cannot be deleted
        status == .reserved
    }

    private func mapStatus(_ status: InvestmentReservationStatus) -> InvestmentReservationStatusDisplay {
        switch status {
        case .reserved, .cancelled:
            // Status 1: Reserved/initial state - can be deleted
            return .reserved
        case .active, .closed, .executing:
            // Status 2: Active - trader started trade - cannot be deleted
            return .active
        case .completed:
            // Status 3: Completed - trader completed trade - cannot be deleted
            return .completed
        }
    }
}

enum InvestmentReservationStatusDisplay {
    case reserved  // Status 1: Initial/reserved state - can be deleted
    case active    // Status 2: Trader started trade - cannot be deleted
    case completed // Status 3: Trader completed trade - cannot be deleted

    var displayColor: Color {
        switch self {
        case .reserved:
            // Status 1: White text (shows with trash icon)
            return AppTheme.fontColor
        case .active:
            // Status 2: Red text for "active"
            return AppTheme.accentRed
        case .completed:
            // Status 3: White text for "compl."
            return AppTheme.fontColor
        }
    }

    var statusNumber: Int {
        switch self {
        case .reserved: return 1
        case .active: return 2
        case .completed: return 3
        }
    }
}

// MARK: - Array Safe Access Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
