import SwiftUI

// MARK: - Trade Status

enum TradeStatus: String, CaseIterable, Codable, Sendable {
    case pending
    case active
    case completed
    case cancelled

    var displayName: String {
        switch self {
        case .pending: return "Ausstehend"
        case .active: return "Aktiv"
        case .completed: return "Abgeschlossen"
        case .cancelled: return "Storniert"
        }
    }

    var color: Color {
        switch self {
        case .pending: return AppTheme.accentOrange
        case .active: return AppTheme.accentLightBlue
        case .completed: return AppTheme.accentGreen
        case .cancelled: return AppTheme.accentRed
        }
    }
}
