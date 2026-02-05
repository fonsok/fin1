import Foundation
import SwiftUI

// MARK: - Order Type
/// Defines whether an order is a buy or sell transaction
enum OrderType: String, CaseIterable, Codable, Sendable {
    case buy
    case sell

    var displayName: String {
        switch self {
        case .buy: return "Buy"
        case .sell: return "Sell"
        }
    }

    var systemImage: String {
        switch self {
        case .buy: return "arrow.up.circle.fill"
        case .sell: return "arrow.down.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .buy: return AppTheme.accentGreen
        case .sell: return AppTheme.accentRed
        }
    }
}











