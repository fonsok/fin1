import Foundation
import Combine
@testable import FIN1

// MARK: - Mock Notification Service
class MockNotificationService: NotificationServiceProtocol {
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Test configuration
    var shouldThrowError = false
    var errorToThrow: AppError = AppError.unknownError("Test error")

    func loadNotifications(for user: User) {
        // no-op for unit tests
    }

    func markAsRead(_ notification: AppNotification) {
        if let index = self.notifications.firstIndex(where: { $0.id == notification.id }) {
            self.notifications[index].isRead = true
            self.unreadCount = self.notifications.filter { !$0.isRead }.count
        }
    }

    func markAllAsRead() {
        for index in self.notifications.indices {
            self.notifications[index].isRead = true
        }
        self.unreadCount = 0
    }

    func deleteNotification(_ notification: AppNotification) {
        notifications.removeAll { $0.id == notification.id }
        unreadCount = notifications.filter { !$0.isRead }.count
    }

    func clearAllNotifications() {
        notifications.removeAll()
        unreadCount = 0
    }

    func createNotification(title: String, message: String, type: NotificationType, priority: NotificationPriority, for userId: String, metadata: [String: String]?) {
        let notification = AppNotification(userId: userId, title: title, message: message, type: type, priority: priority, metadata: metadata)
        notifications.append(notification)
        unreadCount = notifications.filter { !$0.isRead }.count
    }

    func getNotifications(for userId: String) -> [AppNotification] {
        notifications.filter { $0.userId == userId }
    }

    func getUnreadNotifications(for userId: String) -> [AppNotification] {
        notifications.filter { $0.userId == userId && !$0.isRead }
    }

    func getNotificationsByType(_ type: NotificationType, for userId: String) -> [AppNotification] {
        notifications.filter { $0.userId == userId && $0.type == type }
    }

    func getCombinedUnreadCount() -> Int { unreadCount }
    func getCombinedItems() -> [NotificationItem] {
        let notificationItems = notifications.map { NotificationItem.notification($0) }
        return notificationItems
    }

    func start() {}
    func stop() {}
    func reset() {
        notifications.removeAll()
        unreadCount = 0
        isLoading = false
    }
}

// MARK: - Fake Notification Service
class FakeNotificationService: MockNotificationService {}
