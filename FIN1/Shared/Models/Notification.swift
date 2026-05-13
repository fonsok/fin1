import Foundation

// MARK: - Notification Types

enum NotificationType: String, CaseIterable, Codable {
    case investment
    case trader
    case document
    case system
    case security
    case marketing

    var displayName: String {
        switch self {
        case .investment: return "Investment"
        case .trader: return "Trader"
        case .document: return "Document"
        case .system: return "System"
        case .security: return "Security"
        case .marketing: return "Marketing"
        }
    }

    var icon: String {
        switch self {
        case .investment: return "chart.line.uptrend.xyaxis"
        case .trader: return "person.circle"
        case .document: return "doc.text"
        case .system: return "gear"
        case .security: return "shield"
        case .marketing: return "megaphone"
        }
    }
}

enum NotificationPriority: String, CaseIterable, Codable {
    case low
    case medium
    case high
    case urgent

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }

    var color: String {
        switch self {
        case .low: return "blue"
        case .medium: return "orange"
        case .high: return "red"
        case .urgent: return "purple"
        }
    }
}

// MARK: - Notification Models

struct AppNotification: Identifiable, Codable {
    let id: String
    let userId: String
    let title: String
    let message: String
    let type: NotificationType
    /// Raw backend category (Parse `Notification.category`) for accurate semantics and future filtering.
    let serverCategory: String?
    let priority: NotificationPriority
    var isRead: Bool
    var readAt: Date?
    let createdAt: Date
    let metadata: [String: String]? // Store additional data like ticketId

    init(
        id: String = UUID().uuidString,
        userId: String,
        title: String,
        message: String,
        type: NotificationType,
        serverCategory: String? = nil,
        priority: NotificationPriority,
        isRead: Bool = false,
        readAt: Date? = nil,
        createdAt: Date = Date(),
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.message = message
        self.type = type
        self.serverCategory = serverCategory
        self.priority = priority
        self.isRead = isRead
        self.readAt = readAt
        self.createdAt = createdAt
        self.metadata = metadata
    }

    // MARK: - Computed Properties

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self.createdAt, relativeTo: Date())
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self.createdAt)
    }
}

// MARK: - Unified Notification Item (Notification | Document)

enum NotificationItem: Identifiable {
    case notification(AppNotification)
    case document(Document)

    var id: String {
        switch self {
        case .notification(let n): return n.id
        case .document(let d): return d.id
        }
    }

    // Unified read state
    var isRead: Bool {
        switch self {
        case .notification(let n): return n.isRead
        case .document(let d): return d.readAt != nil
        }
    }
}
