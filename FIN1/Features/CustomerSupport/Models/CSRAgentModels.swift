import Foundation

// MARK: - CSR Agent

struct CSRAgent: Identifiable, Codable {
    let id: String
    let name: String
    let email: String
    let specializations: [String]
    let languages: [String]
    var isAvailable: Bool
    var currentTicketCount: Int

    /// Maximum tickets an agent can handle (configurable per-team, default 8 for round-robin)
    static let maxTickets = 8

    var canAcceptTickets: Bool {
        self.isAvailable && self.currentTicketCount < Self.maxTickets
    }

    var workloadPercentage: Double {
        Double(self.currentTicketCount) / Double(Self.maxTickets) * 100
    }

    var hasCapacity: Bool {
        self.currentTicketCount < Self.maxTickets
    }
}

// MARK: - Agent Specialization

/// Standardized specializations for skill-based routing
enum AgentSpecialization: String, Codable, CaseIterable {
    case general = "General Support"
    case account = "Account Management"
    case billing = "Billing & Payments"
    case security = "Security"
    case technical = "Technical Issues"
    case investments = "Investments"
    case refunds = "Refunds"

    var displayName: String {
        switch self {
        case .general: return "Allgemeiner Support"
        case .account: return "Kontoverwaltung"
        case .billing: return "Abrechnung & Zahlungen"
        case .security: return "Sicherheit"
        case .technical: return "Technische Probleme"
        case .investments: return "Investments"
        case .refunds: return "Rückerstattungen"
        }
    }

    var icon: String {
        switch self {
        case .general: return "questionmark.circle.fill"
        case .account: return "person.crop.circle.fill"
        case .billing: return "creditcard.fill"
        case .security: return "lock.shield.fill"
        case .technical: return "wrench.and.screwdriver.fill"
        case .investments: return "chart.line.uptrend.xyaxis"
        case .refunds: return "arrow.uturn.backward.circle.fill"
        }
    }
}

