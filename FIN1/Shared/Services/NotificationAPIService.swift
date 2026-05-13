import Foundation

// MARK: - Notification API Service Protocol

protocol NotificationAPIServiceProtocol: Sendable {
    func fetchNotifications(for userId: String, includeArchived: Bool) async throws -> [AppNotification]
    func markNotificationRead(notificationId: String) async throws
    func markAllNotificationsRead() async throws
}

// MARK: - Parse Notification Response

private struct ParseNotificationResponse: Decodable, Sendable {
    let objectId: String
    let userId: String
    let title: String
    let message: String
    let category: String?
    let priority: String?
    let isRead: Bool?
    let isArchived: Bool?
    let createdAt: String?
    let readAt: String?
    let referenceType: String?
    let referenceId: String?
    let metadata: [String: AnyCodable]?
}

// MARK: - Parse Function Responses

private struct MarkNotificationReadResponse: Decodable {
    let success: Bool
}

private struct MarkAllNotificationsReadResponse: Decodable {
    let success: Bool
    let updated: Int?
}

// MARK: - Notification API Service

final class NotificationAPIService: NotificationAPIServiceProtocol, @unchecked Sendable {
    private let apiClient: ParseAPIClientProtocol
    private let className = "Notification"
    private let pageSize = 100
    private let maxTotal = 500

    init(apiClient: ParseAPIClientProtocol) {
        self.apiClient = apiClient
    }

    func fetchNotifications(for userId: String, includeArchived: Bool = false) async throws -> [AppNotification] {
        // Resource-saving: if we don't have an authenticated session (e.g. offline/simulated auth),
        // skip backend fetch to avoid predictable auth failures and wasted requests.
        if let sessionState = apiClient as? SessionStateProviding, !sessionState.hasAuthenticatedSession {
            return []
        }

        var queryBase: [String: Any] = ["userId": userId]
        if !includeArchived {
            queryBase["isArchived"] = false
        }

        var all: [AppNotification] = []
        var seenIds = Set<String>()
        var cursor: Date?

        while all.count < self.maxTotal {
            var query = queryBase
            if let cursor {
                query["createdAt"] = [
                    "$lt": [
                        "__type": "Date",
                        "iso": Self.isoString(cursor)
                    ]
                ]
            }

            let responses: [ParseNotificationResponse] = try await apiClient.fetchObjects(
                className: self.className,
                query: query,
                include: nil,
                orderBy: "-createdAt",
                limit: self.pageSize
            )

            if responses.isEmpty { break }

            let mapped = responses.compactMap { $0.toAppNotification() }
            for n in mapped where !seenIds.contains(n.id) {
                all.append(n)
                seenIds.insert(n.id)
                if all.count >= maxTotal { break }
            }

            // Advance cursor to the oldest `createdAt` we saw in this page.
            if let oldestCreatedAt = mapped.map(\.createdAt).min() {
                cursor = oldestCreatedAt
            }

            // Last page (Parse returned fewer than requested).
            if responses.count < self.pageSize { break }
        }

        return all.sorted { $0.createdAt > $1.createdAt }
    }

    func markNotificationRead(notificationId: String) async throws {
        let envelope: ParseFunctionEnvelope<MarkNotificationReadResponse> = try await apiClient.callFunction(
            "markNotificationRead",
            parameters: ["notificationId": notificationId]
        )

        guard envelope.result.success else {
            throw NetworkError.invalidResponse
        }
    }

    func markAllNotificationsRead() async throws {
        let envelope: ParseFunctionEnvelope<MarkAllNotificationsReadResponse> = try await apiClient.callFunction(
            "markAllNotificationsRead",
            parameters: nil
        )

        guard envelope.result.success else {
            throw NetworkError.invalidResponse
        }
    }
}

private extension NotificationAPIService {
    static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

// MARK: - Mapping

private extension ParseNotificationResponse {
    func toAppNotification() -> AppNotification? {
        let created = self.createdAt.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
        let readDate = self.readAt.flatMap { ISO8601DateFormatter().date(from: $0) }
        let effectiveReadAt: Date? = {
            guard (self.isRead ?? false) else { return nil }
            return readDate ?? created
        }()

        let mappedType: NotificationType = {
            switch (self.category ?? "").lowercased() {
            case "investment":
                return .investment
            case "trading":
                return .trader
            case "document":
                return .document
            case "security":
                return .security
            case "marketing":
                return .marketing
            case "system", "account", "support", "wallet", "admin":
                return .system
            default:
                return .system
            }
        }()

        let mappedPriority: NotificationPriority = {
            switch (self.priority ?? "").lowercased() {
            case "low":
                return .low
            case "high":
                return .high
            case "urgent":
                return .urgent
            case "normal", "medium":
                return .medium
            default:
                return .medium
            }
        }()

        var mappedMetadata: [String: String] = [:]
        if let referenceType, !referenceType.isEmpty {
            mappedMetadata["referenceType"] = referenceType
        }
        if let referenceId, !referenceId.isEmpty {
            mappedMetadata["referenceId"] = referenceId
        }
        if let metadata {
            for (k, v) in metadata {
                mappedMetadata[k] = String(describing: v.value)
            }
        }

        return AppNotification(
            id: self.objectId,
            userId: self.userId,
            title: self.title,
            message: self.message,
            type: mappedType,
            serverCategory: self.category,
            priority: mappedPriority,
            isRead: self.isRead ?? false,
            readAt: effectiveReadAt,
            createdAt: created,
            metadata: mappedMetadata.isEmpty ? nil : mappedMetadata
        )
    }
}

