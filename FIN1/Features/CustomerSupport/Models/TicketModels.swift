import Foundation

// MARK: - Support Ticket

struct SupportTicket: Identifiable, Codable {
    let id: String
    let ticketNumber: String
    /// Parse `_User.objectId` des Endkunden.
    let userId: String
    let customerName: String
    let subject: String
    let description: String
    var status: TicketStatus
    let priority: TicketPriority
    var assignedTo: String?
    let createdAt: Date
    var updatedAt: Date
    var responses: [TicketResponse]

    // Lifecycle tracking
    var closedAt: Date?
    var archivedAt: Date?
    var parentTicketId: String?  // Reference to previous ticket if reopened as new

    // MARK: - Computed Properties

    /// Check if ticket can be reopened (within 7-day grace period)
    var canReopen: Bool {
        guard self.status == .closed || self.status == .resolved else { return false }
        guard let closedAt = closedAt else { return false }
        let daysSinceClosed = Calendar.current.dateComponents([.day], from: closedAt, to: Date()).day ?? 0
        return daysSinceClosed <= 7
    }

    /// Days remaining to reopen
    var daysUntilReopenExpires: Int? {
        guard self.canReopen, let closedAt = closedAt else { return nil }
        let daysSinceClosed = Calendar.current.dateComponents([.day], from: closedAt, to: Date()).day ?? 0
        return max(0, 7 - daysSinceClosed)
    }

    /// Check if ticket should be auto-archived (30 days after closure)
    var shouldAutoArchive: Bool {
        guard self.status == .closed, self.archivedAt == nil else { return false }
        guard let closedAt = closedAt else { return false }
        let daysSinceClosed = Calendar.current.dateComponents([.day], from: closedAt, to: Date()).day ?? 0
        return daysSinceClosed >= 30
    }

    enum TicketStatus: String, Codable {
        case open
        case inProgress
        case waitingForCustomer
        case escalated
        case resolved
        case closed
        case archived

        var displayName: String {
            switch self {
            case .open: return "Offen"
            case .inProgress: return "In Bearbeitung"
            case .waitingForCustomer: return "Wartet auf Kunde"
            case .escalated: return "Eskaliert"
            case .resolved: return "Gelöst"
            case .closed: return "Geschlossen"
            case .archived: return "Archiviert"
            }
        }

        var isActive: Bool {
            switch self {
            case .open, .inProgress, .waitingForCustomer, .escalated:
                return true
            case .resolved, .closed, .archived:
                return false
            }
        }
    }

    enum TicketPriority: String, Codable {
        case low
        case medium
        case high
        case urgent

        var displayName: String {
            switch self {
            case .low: return "Niedrig"
            case .medium: return "Mittel"
            case .high: return "Hoch"
            case .urgent: return "Dringend"
            }
        }
    }
}

// MARK: - Ticket Response

struct TicketResponse: Identifiable, Codable {
    let id: String
    let agentId: String
    let agentName: String
    let message: String
    let isInternal: Bool
    let createdAt: Date
    let responseType: TicketResponseType
    let solutionDetails: SolutionDetails?

    init(
        id: String,
        agentId: String,
        agentName: String,
        message: String,
        isInternal: Bool,
        createdAt: Date,
        responseType: TicketResponseType = .message,
        solutionDetails: SolutionDetails? = nil
    ) {
        self.id = id
        self.agentId = agentId
        self.agentName = agentName
        self.message = message
        self.isInternal = isInternal
        self.createdAt = createdAt
        self.responseType = responseType
        self.solutionDetails = solutionDetails
    }
}

// MARK: - Ticket Response Types

enum TicketResponseType: String, Codable, CaseIterable {
    case message           // Regular response to customer
    case internalNote      // Internal note (not visible to customer)
    case solution          // Solution provided
    case escalation        // Escalated to another team
    case statusChange      // Status was changed
    case assignment        // Ticket was assigned

    var displayName: String {
        switch self {
        case .message: return "Nachricht"
        case .internalNote: return "Interne Notiz"
        case .solution: return "Lösung"
        case .escalation: return "Eskalation"
        case .statusChange: return "Statusänderung"
        case .assignment: return "Zuweisung"
        }
    }

    var icon: String {
        switch self {
        case .message: return "bubble.left.fill"
        case .internalNote: return "note.text"
        case .solution: return "checkmark.seal.fill"
        case .escalation: return "arrow.up.circle.fill"
        case .statusChange: return "arrow.triangle.2.circlepath"
        case .assignment: return "person.badge.plus"
        }
    }
}

// MARK: - Ticket Create DTO

struct SupportTicketCreate: Codable {
    let userId: String
    let subject: String
    let description: String
    let priority: SupportTicket.TicketPriority
}

