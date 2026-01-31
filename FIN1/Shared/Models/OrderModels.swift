import Foundation

// MARK: - Order Models
/// Shared order-related models to eliminate duplication across ViewModels

/// Standardized order mode enum
enum OrderMode: String, CaseIterable, Identifiable {
    case market = "market"
    case limit = "limit"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .market: return "Market"
        case .limit: return "Limit"
        }
    }
}
