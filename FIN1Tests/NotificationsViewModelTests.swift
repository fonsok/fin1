import XCTest
@testable import FIN1

@MainActor
final class NotificationsViewModelTests: XCTestCase {
    func testScopesItemsToCurrentUser() async {
        let notificationService = MockNotificationService()
        let documentService = MockDocumentService()
        let userService = MockUserService()

        _ = await TestHelpers.createInvestorUser(mockUserService: userService)
        let userId = userService.currentUser?.id ?? "user1"
        userService.currentUser?.role = .investor

        notificationService.notifications = [
            AppNotification(userId: userId, title: "N1", message: "", type: .investment, priority: .medium, isRead: false, createdAt: Date()),
            AppNotification(userId: "otherUser", title: "N2", message: "", type: .investment, priority: .medium, isRead: false, createdAt: Date())
        ]

        let d1 = Document(userId: userId, name: "D1", type: .other, status: .verified, fileURL: "file://d1", size: 1, uploadedAt: Date())
        let d2 = Document(userId: "otherUser", name: "D2", type: .other, status: .verified, fileURL: "file://d2", size: 1, uploadedAt: Date())
        documentService.documents = [d1, d2]

        let vm = NotificationsViewModel(
            notificationService: notificationService,
            documentService: documentService,
            userService: userService
        )

        // Investor role defaults to `.investments`, so only user1 investment notifications should be shown.
        XCTAssertEqual(vm.filteredItems.count, 1)
        XCTAssertEqual(vm.filteredItems.first?.id, notificationService.notifications.first?.id)
    }

    func testRecentReadWindowExcludesOldReadItems() async {
        let notificationService = MockNotificationService()
        let documentService = MockDocumentService()
        let userService = MockUserService()

        _ = await TestHelpers.createInvestorUser(mockUserService: userService)
        let userId = userService.currentUser?.id ?? "user1"

        let now = Date()
        let oldReadAt = now.addingTimeInterval(-90_000) // > 24h
        let recentReadAt = now.addingTimeInterval(-3_600) // 1h

        notificationService.notifications = [
            AppNotification(userId: userId, title: "Unread", message: "", type: .investment, priority: .medium, isRead: false, createdAt: now),
            AppNotification(userId: userId, title: "OldRead", message: "", type: .investment, priority: .medium, isRead: true, readAt: oldReadAt, createdAt: now),
            AppNotification(userId: userId, title: "RecentRead", message: "", type: .investment, priority: .medium, isRead: true, readAt: recentReadAt, createdAt: now)
        ]

        let vm = NotificationsViewModel(
            notificationService: notificationService,
            documentService: documentService,
            userService: userService
        )

        // Default filter is `.investments` for investor, so we can check the window directly.
        let titles = vm.filteredItems.compactMap { item -> String? in
            if case .notification(let n) = item { return n.title }
            return nil
        }

        XCTAssertTrue(titles.contains("Unread"))
        XCTAssertTrue(titles.contains("RecentRead"))
        XCTAssertFalse(titles.contains("OldRead"))
    }

    func testDocumentsFilterShowsOnlyDocuments() async {
        let notificationService = MockNotificationService()
        let documentService = MockDocumentService()
        let userService = MockUserService()

        _ = await TestHelpers.createInvestorUser(mockUserService: userService)
        let userId = userService.currentUser?.id ?? "user1"

        notificationService.notifications = [
            AppNotification(userId: userId, title: "N1", message: "", type: .investment, priority: .medium, isRead: false, createdAt: Date())
        ]

        let d1 = Document(userId: userId, name: "D1", type: .other, status: .verified, fileURL: "file://d1", size: 1, uploadedAt: Date())
        documentService.documents = [d1]

        let vm = NotificationsViewModel(
            notificationService: notificationService,
            documentService: documentService,
            userService: userService
        )

        vm.selectedFilter = .documents
        await Task.yield()

        XCTAssertEqual(vm.filteredItems.count, 1)
        if case .document(let doc) = vm.filteredItems.first {
            XCTAssertEqual(doc.id, d1.id)
        } else {
            XCTFail("Expected a document item")
        }
    }

    func testRoleDefaultFilterInvestorAndTrader() async {
        let notificationService = MockNotificationService()
        let documentService = MockDocumentService()
        let userService = MockUserService()

        // Investor → `.investments`
        _ = await TestHelpers.createInvestorUser(mockUserService: userService)
        var vm = NotificationsViewModel(
            notificationService: notificationService,
            documentService: documentService,
            userService: userService
        )
        XCTAssertEqual(vm.selectedFilter, .investments)

        // Trader → `.trades`
        _ = await TestHelpers.createTraderUser(mockUserService: userService)
        vm = NotificationsViewModel(
            notificationService: notificationService,
            documentService: documentService,
            userService: userService
        )
        XCTAssertEqual(vm.selectedFilter, .trades)
    }

    func testArchivedCountAndHiddenOlderItems() async {
        let notificationService = MockNotificationService()
        let documentService = MockDocumentService()
        let userService = MockUserService()

        _ = await TestHelpers.createInvestorUser(mockUserService: userService)
        let userId = userService.currentUser?.id ?? "user1"

        let now = Date()
        let oldReadAt = now.addingTimeInterval(-90_000) // > 24h
        let recentReadAt = now.addingTimeInterval(-3_600) // 1h

        notificationService.notifications = [
            AppNotification(
                userId: userId,
                title: "Unread",
                message: "",
                type: .investment,
                priority: .medium,
                isRead: false,
                createdAt: now
            ),
            AppNotification(
                userId: userId,
                title: "RecentRead",
                message: "",
                type: .investment,
                priority: .medium,
                isRead: true,
                readAt: recentReadAt,
                createdAt: now
            ),
            AppNotification(
                userId: userId,
                title: "OldRead",
                message: "",
                type: .investment,
                priority: .medium,
                isRead: true,
                readAt: oldReadAt,
                createdAt: now
            )
        ]

        // Default filter is `.investments`, so all 3 match by type.
        let vm = NotificationsViewModel(
            notificationService: notificationService,
            documentService: documentService,
            userService: userService
        )

        XCTAssertTrue(vm.hasHiddenOlderItems)
        XCTAssertEqual(vm.filteredItems.count, 2, "Only unread + recent read should be shown")
        XCTAssertEqual(vm.archivedCount, 1, "Old read items should be treated as archived/hidden")
    }

    func testSupportCategoryNotIncludedInSystemFilterButIncludedInAll() async {
        let notificationService = MockNotificationService()
        let documentService = MockDocumentService()
        let userService = MockUserService()

        _ = await TestHelpers.createInvestorUser(mockUserService: userService)
        let userId = userService.currentUser?.id ?? "user1"

        let support = AppNotification(
            userId: userId,
            title: "Support",
            message: "",
            type: .system,
            serverCategory: "support",
            priority: .medium,
            isRead: false,
            createdAt: Date(),
            metadata: ["ticketId": "T-1"]
        )

        let system = AppNotification(
            userId: userId,
            title: "System",
            message: "",
            type: .system,
            serverCategory: "system",
            priority: .medium,
            isRead: false,
            createdAt: Date()
        )

        notificationService.notifications = [support, system]

        let vm = NotificationsViewModel(
            notificationService: notificationService,
            documentService: documentService,
            userService: userService
        )

        vm.selectedFilter = .all
        // Allow Combine pipeline to deliver and recompute.
        let deadline = Date().addingTimeInterval(0.5)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            if vm.filteredItems.contains(where: { item in
                if case .notification(let n) = item { return n.title == "Support" }
                return false
            }) {
                break
            }
        }
        let allTitles = vm.filteredItems.compactMap { item -> String? in
            if case .notification(let n) = item { return n.title }
            return nil
        }
        XCTAssertTrue(allTitles.contains("Support"), "Expected Support in .all, got: \(allTitles)")
        XCTAssertTrue(allTitles.contains("System"), "Expected System in .all, got: \(allTitles)")

        if let supportItem = vm.filteredItems.compactMap({ item -> AppNotification? in
            if case .notification(let n) = item, n.title == "Support" { return n }
            return nil
        }).first {
            XCTAssertEqual(supportItem.serverCategory, "support")
            XCTAssertEqual(supportItem.metadata?["ticketId"], "T-1")
        } else {
            XCTFail("Missing Support item in .all")
        }

        vm.selectedFilter = .system
        let systemDeadline = Date().addingTimeInterval(0.5)
        while Date() < systemDeadline {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            if vm.filteredItems.contains(where: { item in
                if case .notification(let n) = item { return n.title == "Support" }
                return false
            }) == false {
                break
            }
        }
        XCTAssertEqual(vm.selectedFilter, .system)
        let systemTitles = vm.filteredItems.compactMap { item -> String? in
            if case .notification(let n) = item { return n.title }
            return nil
        }
        XCTAssertFalse(systemTitles.contains("Support"), "Expected Support excluded from .system, got: \(systemTitles)")
        XCTAssertTrue(systemTitles.contains("System"), "Expected System included in .system, got: \(systemTitles)")
    }
}

