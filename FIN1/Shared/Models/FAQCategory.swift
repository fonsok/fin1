import Foundation

/// Categories for organizing FAQs
enum FAQCategory: String, CaseIterable, Identifiable {
    case gettingStarted = "Getting Started"
    case appOverview = "App Overview"
    case investments = "Investments"
    case trading = "Trading"
    case portfolio = "Investments & Performance"
    case invoices = "Invoices & Statements"
    case security = "Security & Authentication"
    case notifications = "Notifications"
    case technical = "Technical Support"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .gettingStarted: return "arrow.right.circle.fill"
        case .appOverview: return "star.fill"
        case .investments: return "dollarsign.circle.fill"
        case .trading: return "chart.line.uptrend.xyaxis"
        case .portfolio: return "chart.bar.fill"
        case .invoices: return "doc.text.fill"
        case .security: return "lock.shield.fill"
        case .notifications: return "bell.fill"
        case .technical: return "wrench.and.screwdriver.fill"
        }
    }
}





