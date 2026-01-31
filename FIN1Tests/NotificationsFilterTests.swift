import XCTest
@testable import FIN1

final class NotificationsFilterTests: XCTestCase {
    func testCombinedUnreadCountAndFilterByType() {
        // Seed notifications
        let now = Date()
        let seed: [AppNotification] = [
            AppNotification(userId: "user1", title: "A", message: "", type: .investment, priority: .medium, isRead: false, createdAt: now),
            AppNotification(userId: "user1", title: "B", message: "", type: .system, priority: .low, isRead: true, createdAt: now),
            AppNotification(userId: "user1", title: "C", message: "", type: .trader, priority: .high, isRead: false, createdAt: now)
        ]
        let svc = MockNotificationService()
        // Preload notifications
        svc.notifications = seed

        XCTAssertEqual(svc.getCombinedUnreadCount(), 2)

        let inv = svc.getNotificationsByType(.investment, for: "user1")
        XCTAssertEqual(inv.count, 1)
        XCTAssertEqual(inv.first?.title, "A")

        svc.markAllAsRead()
        XCTAssertEqual(svc.getCombinedUnreadCount(), 0)
    }
}
