import Foundation

enum NotificationCardAction: Equatable {
    case survey(requestId: String)
    case ticket(ticketId: String)
    case none
}

/// Central place to interpret `AppNotification.metadata` for deep-links.
/// Keeps routing/business rules out of SwiftUI view bodies.
enum NotificationMetadataActionResolver {
    static func resolve(for notification: AppNotification) -> NotificationCardAction {
        // 1) Survey notifications
        if let surveyRequestId = notification.metadata?["surveyRequestId"], !surveyRequestId.isEmpty {
            return .survey(requestId: surveyRequestId)
        }

        // 2) Ticket notifications (explicit key)
        if let ticketId = notification.metadata?["ticketId"], !ticketId.isEmpty {
            return .ticket(ticketId: ticketId)
        }

        // 3) Parse-backed notifications often use referenceType/referenceId
        if notification.metadata?["referenceType"] == "ticket",
           let ticketId = notification.metadata?["referenceId"],
           !ticketId.isEmpty {
            return .ticket(ticketId: ticketId)
        }

        return .none
    }
}

