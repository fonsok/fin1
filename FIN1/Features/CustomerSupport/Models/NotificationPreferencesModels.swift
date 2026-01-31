import Foundation

// MARK: - Support Notification Preferences

/// User preferences for support-related notifications
struct SupportNotificationPreferences: Codable {
    // Ticket Updates
    var newTicketResponse: Bool
    var ticketStatusChange: Bool
    var ticketResolved: Bool
    var ticketClosed: Bool

    // Agent Actions (for CSRs)
    var newTicketAssigned: Bool
    var slaWarning: Bool
    var escalationAlert: Bool
    var surveyRequest: Bool

    // Delivery Methods
    var pushNotifications: Bool
    var emailNotifications: Bool
    var inAppNotifications: Bool

    // Quiet Hours
    var quietHoursEnabled: Bool
    var quietHoursStart: Int  // Hour (0-23)
    var quietHoursEnd: Int    // Hour (0-23)

    static let `default` = SupportNotificationPreferences(
        newTicketResponse: true,
        ticketStatusChange: true,
        ticketResolved: true,
        ticketClosed: true,
        newTicketAssigned: true,
        slaWarning: true,
        escalationAlert: true,
        surveyRequest: true,
        pushNotifications: true,
        emailNotifications: true,
        inAppNotifications: true,
        quietHoursEnabled: false,
        quietHoursStart: 22,
        quietHoursEnd: 7
    )
}

// MARK: - Notification Preference Category

enum NotificationPreferenceCategory: String, CaseIterable {
    case ticketUpdates = "Ticket-Updates"
    case agentNotifications = "Agent-Benachrichtigungen"
    case deliveryMethods = "Zustellmethoden"
    case quietHours = "Ruhezeiten"

    var icon: String {
        switch self {
        case .ticketUpdates: return "ticket.fill"
        case .agentNotifications: return "person.badge.clock.fill"
        case .deliveryMethods: return "paperplane.fill"
        case .quietHours: return "moon.fill"
        }
    }
}

