import Foundation
import SwiftUI

// MARK: - Order Buy Status
/// Status progression for buy orders: submitted → suspended → executed → confirmed → completed
enum OrderBuyStatus: String, CaseIterable, Codable {
    case submitted     // Status 1: Order placed
    case suspended     // Status 2: Trading suspended
    case executed      // Status 3: Order executed
    case confirmed     // Status 4: Order confirmed
    case completed     // Status 5: Order completed (final status)
    case cancelled

    var displayName: String {
        switch self {
        case .submitted: return "Submitted"
        case .suspended: return "Trading Suspended"
        case .executed: return "Executed"
        case .confirmed: return "Confirmed"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var code: Int {
        switch self {
        case .submitted: return 1
        case .suspended: return 2
        case .executed: return 3
        case .confirmed: return 4
        case .completed: return 5
        case .cancelled: return 0
        }
    }

    var color: Color {
        switch self {
        case .submitted: return AppTheme.accentOrange
        case .suspended: return AppTheme.accentOrange
        case .executed: return AppTheme.accentLightBlue
        case .confirmed: return AppTheme.accentLightBlue
        case .completed: return AppTheme.accentGreen
        case .cancelled: return AppTheme.accentRed
        }
    }
}

// MARK: - Order Sell Status
/// Status progression for sell orders: submitted → suspended → executed → confirmed → completed
enum OrderSellStatus: String, CaseIterable, Codable {
    case submitted     // Status 1: Order placed
    case suspended     // Status 2: Trading suspended
    case executed      // Status 3: Order executed
    case confirmed     // Status 4: Order confirmed
    case completed     // Status 5: Order completed (final status)
    case cancelled

    var displayName: String {
        switch self {
        case .submitted: return "Submitted"
        case .suspended: return "Trading Suspended"
        case .executed: return "Executed"
        case .confirmed: return "Confirmed"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var code: Int {
        switch self {
        case .submitted: return 1
        case .suspended: return 2
        case .executed: return 3
        case .confirmed: return 4
        case .completed: return 5
        case .cancelled: return 0
        }
    }

    var color: Color {
        switch self {
        case .submitted: return AppTheme.accentOrange
        case .suspended: return AppTheme.accentOrange
        case .executed: return AppTheme.accentLightBlue
        case .confirmed: return AppTheme.accentLightBlue
        case .completed: return AppTheme.accentGreen
        case .cancelled: return AppTheme.accentRed
        }
    }
}











