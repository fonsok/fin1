import Foundation

/// Bundled fallback support only (server-driven categories should be preferred).
extension FAQCategory {
    var slug: String {
        switch self {
        case .gettingStarted: return "getting_started"
        case .appOverview: return "app_overview"
        case .investments: return "investments"
        case .trading: return "trading"
        case .portfolio: return "portfolio" // API compatibility; display name: "Investments & Performance"
        case .invoices: return "invoices"
        case .security: return "security"
        case .notifications: return "notifications"
        case .technical: return "technical"
        }
    }
}

