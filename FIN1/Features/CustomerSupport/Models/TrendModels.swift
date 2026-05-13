import Foundation

// MARK: - Support Trend

/// Represents a detected trend in support tickets
struct SupportTrend: Identifiable, Codable {
    let id: String
    let type: TrendType
    let title: String
    let description: String
    let severity: TrendSeverity
    let ticketCount: Int
    let affectedCustomers: Int
    let percentageChange: Double  // vs previous period
    let detectedAt: Date
    let relatedTicketIds: [String]
    let suggestedAction: String

    enum TrendType: String, Codable, CaseIterable {
        case volumeSpike = "Volume Spike"
        case recurringIssue = "Recurring Issue"
        case longResolutionTime = "Long Resolution Time"
        case highEscalationRate = "High Escalation Rate"
        case negativeCSAT = "Negative CSAT"
        case reopenedTickets = "Reopened Tickets"

        var icon: String {
            switch self {
            case .volumeSpike: return "chart.line.uptrend.xyaxis"
            case .recurringIssue: return "arrow.triangle.2.circlepath"
            case .longResolutionTime: return "clock.badge.exclamationmark"
            case .highEscalationRate: return "arrow.up.circle.fill"
            case .negativeCSAT: return "hand.thumbsdown.fill"
            case .reopenedTickets: return "arrow.counterclockwise"
            }
        }

        var displayName: String {
            switch self {
            case .volumeSpike: return "Ticket-Anstieg"
            case .recurringIssue: return "Wiederkehrendes Problem"
            case .longResolutionTime: return "Lange Lösungszeit"
            case .highEscalationRate: return "Hohe Eskalationsrate"
            case .negativeCSAT: return "Negative Bewertungen"
            case .reopenedTickets: return "Wiedereröffnete Tickets"
            }
        }
    }

    enum TrendSeverity: String, Codable {
        case info = "Info"
        case warning = "Warnung"
        case critical = "Kritisch"

        var color: String {
            switch self {
            case .info: return "blue"
            case .warning: return "orange"
            case .critical: return "red"
            }
        }
    }
}

// MARK: - Trend Alert

/// Alert generated from a detected trend
struct TrendAlert: Identifiable, Codable {
    let id: String
    let trend: SupportTrend
    let createdAt: Date
    var isRead: Bool
    var isDismissed: Bool
    var acknowledgedBy: String?
    var acknowledgedAt: Date?

    init(trend: SupportTrend) {
        self.id = UUID().uuidString
        self.trend = trend
        self.createdAt = Date()
        self.isRead = false
        self.isDismissed = false
        self.acknowledgedBy = nil
        self.acknowledgedAt = nil
    }
}

// MARK: - Trend Detection Configuration

struct TrendDetectionConfig {
    /// Minimum ticket count to trigger a volume spike alert
    var volumeSpikeThreshold: Int = 10

    /// Percentage increase to consider a spike (e.g., 50% = 1.5x)
    var volumeSpikePercentage: Double = 50

    /// Minimum occurrences to flag as recurring issue
    var recurringIssueThreshold: Int = 5

    /// Hours beyond which resolution is considered slow
    var longResolutionHours: Double = 48

    /// Escalation rate percentage to trigger alert
    var highEscalationRateThreshold: Double = 20

    /// CSAT score below which to trigger alert
    var lowCSATThreshold: Double = 3.0

    /// Reopen rate percentage to trigger alert
    var highReopenRateThreshold: Double = 15

    static let `default` = TrendDetectionConfig()
}

// MARK: - Issue Category (for grouping recurring issues)

struct IssueCategory: Identifiable, Codable {
    let id: String
    let name: String
    let keywords: [String]
    var ticketCount: Int
    var lastOccurrence: Date

    static let predefinedCategories: [IssueCategory] = [
        IssueCategory(
            id: "login",
            name: "Login-Probleme",
            keywords: ["login", "anmelden", "passwort", "einloggen", "zugang"],
            ticketCount: 0,
            lastOccurrence: Date()
        ),
        IssueCategory(
            id: "payment",
            name: "Zahlungsprobleme",
            keywords: ["zahlung", "überweisung", "geld", "konto", "transaktion", "abbuchung"],
            ticketCount: 0,
            lastOccurrence: Date()
        ),
        IssueCategory(
            id: "technical",
            name: "Technische Probleme",
            keywords: ["fehler", "absturz", "bug", "laden", "langsam", "app"],
            ticketCount: 0,
            lastOccurrence: Date()
        ),
        IssueCategory(
            id: "investment",
            name: "Investment-Fragen",
            keywords: ["investition", "anlage", "rendite", "investments", "aktie"],
            ticketCount: 0,
            lastOccurrence: Date()
        ),
        IssueCategory(
            id: "account",
            name: "Konto-Probleme",
            keywords: ["konto", "profil", "daten", "ändern", "löschen"],
            ticketCount: 0,
            lastOccurrence: Date()
        )
    ]
}

