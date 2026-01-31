import Foundation
import SwiftUI

// MARK: - CSR Role
/// Defines the role hierarchy for Customer Service Representatives
enum CSRRole: String, CaseIterable, Codable {
    case level1 = "L1"
    case level2 = "L2"
    case fraud = "Fraud"
    case compliance = "Compliance"
    case techSupport = "Tech Support"
    case teamlead = "Teamlead"

    var displayName: String {
        switch self {
        case .level1: return "Level 1 Support"
        case .level2: return "Level 2 Support"
        case .fraud: return "Fraud Analyst"
        case .compliance: return "Compliance Officer"
        case .techSupport: return "Tech Support"
        case .teamlead: return "Teamlead"
        }
    }

    /// Short name for compact UI display
    var shortName: String {
        switch self {
        case .level1: return "L1"
        case .level2: return "L2"
        case .fraud: return "Fraud"
        case .compliance: return "Compliance"
        case .techSupport: return "Tech"
        case .teamlead: return "Lead"
        }
    }

    /// Icon for UI display
    var icon: String {
        switch self {
        case .level1: return "1.circle.fill"
        case .level2: return "2.circle.fill"
        case .fraud: return "exclamationmark.shield.fill"
        case .compliance: return "checkmark.shield.fill"
        case .techSupport: return "wrench.and.screwdriver.fill"
        case .teamlead: return "star.fill"
        }
    }

    /// Color for UI display
    var color: Color {
        switch self {
        case .level1, .level2: return AppTheme.accentLightBlue
        case .fraud: return AppTheme.accentRed
        case .compliance: return AppTheme.accentGreen
        case .techSupport: return AppTheme.accentOrange
        case .teamlead: return Color.yellow
        }
    }

    var permissions: Set<CustomerSupportPermission> {
        CustomerSupportPermissionSet.forRole(self)
    }

    /// Whether this role can approve 4-Augen requests
    var canApprove: Bool {
        switch self {
        case .teamlead, .compliance:
            return true
        default:
            return false
        }
    }
}
