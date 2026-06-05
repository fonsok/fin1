import Foundation
import SwiftUI

// MARK: - Trader risk level (shared by InvestorTrader + MockTrader)

enum TraderRiskLevel: String, CaseIterable, Codable, Sendable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var displayName: String { rawValue }

    var color: Color {
        switch self {
        case .low: return AppTheme.accentGreen
        case .medium: return AppTheme.accentOrange
        case .high: return AppTheme.accentRed
        }
    }
}
