import Foundation

/// Bundled fallback support only (server-driven categories should be preferred).
extension FAQCategory {
    var slug: String {
        switch self {
        case .gettingStarted: return "getting_started"
        case .platformOverview: return "platform_overview"
        case .investments: return "investments"
        case .trading: return "trading"
        case .portfolio: return "portfolio"
        case .invoices: return "invoices"
        case .security: return "security"
        case .notifications: return "notifications"
        case .technical: return "technical"
        }
    }
}

