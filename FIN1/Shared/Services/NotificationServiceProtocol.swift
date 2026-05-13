import Combine
import Foundation
import SwiftUI

// MARK: - Notification Service Protocol
/// Defines the contract for notification operations and management
protocol NotificationServiceProtocol: ObservableObject {
    var notifications: [AppNotification] { get }
    var notificationsPublisher: AnyPublisher<[AppNotification], Never> { get }
    var unreadCount: Int { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // MARK: - Notification Management
    func loadNotifications(for user: User)
    func markAsRead(_ notification: AppNotification)
    func markAllAsRead()
    func deleteNotification(_ notification: AppNotification)
    func clearAllNotifications()

    // MARK: - Notification Creation
    func createNotification(
        title: String,
        message: String,
        type: NotificationType,
        priority: NotificationPriority,
        for userId: String,
        metadata: [String: String]?
    )

    // MARK: - Notification Queries
    func getNotifications(for userId: String) -> [AppNotification]
    func getUnreadNotifications(for userId: String) -> [AppNotification]
    func getNotificationsByType(_ type: NotificationType, for userId: String) -> [AppNotification]

    // MARK: - Combined Notification Methods
    func getCombinedUnreadCount(for userId: String?) -> Int
    func getCombinedItems() -> [NotificationItem]

    // MARK: - Push Token Management
    func registerPushToken(_ token: String, tokenType: PushTokenType, userId: String, deviceId: String?) async throws
    func deactivatePushToken(_ token: String, tokenType: PushTokenType, userId: String) async throws
    func syncPushTokensToBackend(for userId: String) async
}

// MARK: - Notification Service Implementation
/// Handles notification operations, storage, and user notifications
final class NotificationService: NotificationServiceProtocol, ServiceLifecycle, @unchecked Sendable {
    static let shared = NotificationService()

    @Published var notifications: [AppNotification] = []
    var notificationsPublisher: AnyPublisher<[AppNotification], Never> {
        self.$notifications.eraseToAnyPublisher()
    }
    @Published var unreadCount: Int = 0
    @Published var combinedUnreadCount: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let documentService: any DocumentServiceProtocol
    private let notificationAPIService: NotificationAPIServiceProtocol?
    private var pushTokenAPIService: PushTokenAPIServiceProtocol?

    // Store current push token for sync
    private var currentPushToken: (token: String, type: PushTokenType, deviceId: String?)?

    init(
        documentService: any DocumentServiceProtocol = DocumentService.shared,
        notificationAPIService: NotificationAPIServiceProtocol? = nil,
        pushTokenAPIService: PushTokenAPIServiceProtocol? = nil
    ) {
        self.documentService = documentService
        self.notificationAPIService = notificationAPIService
        self.pushTokenAPIService = pushTokenAPIService

        // Start with empty notifications - notifications will be loaded from actual data sources
        self.notifications = []
        self.updateUnreadCount()
        self.updateCombinedUnreadCount()

        // Debug: Log instance creation
        print("🔔 NotificationService.init: Created new instance \(ObjectIdentifier(self))")

        // Observe document changes to update badge count when documents are added/read
        // Use the injected documentService instead of DocumentService.shared to ensure we observe the correct instance
        // Cast to concrete DocumentService type to access @Published property publisher
        if let concreteDocumentService = documentService as? DocumentService {
            concreteDocumentService.$documents
                .receive(on: DispatchQueue.main)
                .sink { [weak self] documents in
                    print("🔔 NotificationService: Documents changed, count: \(documents.count)")
                    guard let self = self else {
                        print("⚠️ NotificationService: self is nil in document observation sink")
                        return
                    }
                    self.updateUnreadCount()
                    self.updateCombinedUnreadCount()
                }
                .store(in: &self.cancellables)

            print("✅ NotificationService: Document observation set up, observing \(documentService.documents.count) documents")
        } else {
            print("⚠️ NotificationService: documentService is not a DocumentService instance, observation may not work")
        }
    }

    // MARK: - ServiceLifecycle
    func start() { /* e.g., schedule refresh */ }
    func stop() { /* stop timers */ }
    func reset() {
        print("⚠️ NotificationService.reset: Resetting instance \(ObjectIdentifier(self))")
        self.clearAllNotifications()
    }

    // MARK: - Notification Management

    func loadNotifications(for user: User) {
        let uid = user.id
        self.isLoading = true
        self.errorMessage = nil

        guard let api = notificationAPIService else {
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
                self?.updateUnreadCount()
                self?.updateCombinedUnreadCount()
            }
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let fetched = try await api.fetchNotifications(for: uid, includeArchived: false)
                self.applyMergedServerNotifications(fetched: fetched, userId: uid)
                self.isLoading = false
                self.updateUnreadCount()
                self.updateCombinedUnreadCount()
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                self.updateUnreadCount()
                self.updateCombinedUnreadCount()
            }
        }
    }

    /// Keeps client-only rows (e.g. UUID ids) for this user; replaces overlapping ids with server payload.
    private func applyMergedServerNotifications(fetched: [AppNotification], userId: String) {
        let serverIds = Set(fetched.map(\.id))
        let localsForUser = self.notifications.filter { $0.userId == userId && !serverIds.contains($0.id) }
        var merged = fetched + localsForUser
        merged.sort { $0.createdAt > $1.createdAt }
        self.notifications = merged
    }

    func markAsRead(_ notification: AppNotification) {
        if let api = notificationAPIService {
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    try await api.markNotificationRead(notificationId: notification.id)
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            var updatedNotification = self.notifications[index]
            updatedNotification.isRead = true
            updatedNotification.readAt = Date()
            self.notifications[index] = updatedNotification
            self.updateUnreadCount()
            self.updateCombinedUnreadCount()
        }
    }

    func markAllAsRead() {
        if let api = notificationAPIService {
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    try await api.markAllNotificationsRead()
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
        for i in 0..<self.notifications.count {
            self.notifications[i].isRead = true
            self.notifications[i].readAt = Date()
        }
        self.updateUnreadCount()
        self.updateCombinedUnreadCount()
    }

    func deleteNotification(_ notification: AppNotification) {
        self.notifications.removeAll { $0.id == notification.id }
        self.updateUnreadCount()
        self.updateCombinedUnreadCount()
    }

    func clearAllNotifications() {
        print("⚠️ NotificationService.clearAllNotifications: Clearing all notifications from instance \(ObjectIdentifier(self))")
        self.notifications.removeAll()
        self.updateUnreadCount()
        self.updateCombinedUnreadCount()
    }

    // MARK: - Notification Creation

    func createNotification(
        title: String,
        message: String,
        type: NotificationType,
        priority: NotificationPriority,
        for userId: String,
        metadata: [String: String]?
    ) {
        // Ensure we're on MainActor to update @Published properties
        if Thread.isMainThread {
            // Already on main thread, use MainActor.assumeIsolated
            MainActor.assumeIsolated {
                self.createNotificationOnMainThread(
                    title: title,
                    message: message,
                    type: type,
                    priority: priority,
                    for: userId,
                    metadata: metadata
                )
            }
        } else {
            // Use DispatchQueue.main.sync to ensure synchronous execution
            DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    self.createNotificationOnMainThread(
                        title: title,
                        message: message,
                        type: type,
                        priority: priority,
                        for: userId,
                        metadata: metadata
                    )
                }
            }
        }
    }

    @MainActor
    private func createNotificationOnMainThread(
        title: String,
        message: String,
        type: NotificationType,
        priority: NotificationPriority,
        for userId: String,
        metadata: [String: String]?
    ) {
        let notification = AppNotification(
            id: UUID().uuidString,
            userId: userId,
            title: title,
            message: message,
            type: type,
            priority: priority,
            isRead: false,
            createdAt: Date(),
            metadata: metadata
        )

        self.notifications.append(notification)
        self.updateUnreadCount()
        self.updateCombinedUnreadCount()

        print(
            "✅ NotificationService.createNotification: Added notification for userId '\(userId)', total notifications: \(self.notifications.count)"
        )
        print("   📋 Notification details: title='\(title)', type=\(type), userId='\(userId)'")
        print("   🔍 NotificationService instance: \(ObjectIdentifier(self))")

        // Debug: Print all notifications for this user
        let userNotifications = self.notifications.filter { $0.userId == userId }
        print("   📊 User '\(userId)' now has \(userNotifications.count) total notifications")
    }

    // MARK: - Notification Queries

    func getNotifications(for userId: String) -> [AppNotification] {
        return self.notifications.filter { $0.userId == userId }
    }

    func getUnreadNotifications(for userId: String) -> [AppNotification] {
        return self.notifications.filter { $0.userId == userId && !$0.isRead }
    }

    func getNotificationsByType(_ type: NotificationType, for userId: String) -> [AppNotification] {
        return self.notifications.filter { $0.userId == userId && $0.type == type }
    }

    // MARK: - Private Methods

    private func updateUnreadCount() {
        self.unreadCount = self.notifications.filter { !$0.isRead }.count
    }

    private func updateCombinedUnreadCount() {
        // Update combined count for current user (if available)
        // This will be recalculated per-user in getCombinedUnreadCount()
        // but we publish it so views can observe changes
        let unreadNotifications = self.notifications.filter { !$0.isRead }.count
        let unreadDocuments = self.documentService.documents.filter {
            $0.readAt == nil && !$0.isExcludedFromInvestorDocumentInbox
        }.count
        let newCount = unreadNotifications + unreadDocuments
        if self.combinedUnreadCount != newCount {
            self.combinedUnreadCount = newCount
            print(
                "🔔 NotificationService: Updated combinedUnreadCount to \(newCount) (notifications: \(unreadNotifications), documents: \(unreadDocuments))"
            )
        }
    }

    // MARK: - Combined Notification Methods

    func getCombinedUnreadCount(for userId: String? = nil) -> Int {
        // Count unread notifications (filter by userId if provided)
        let unreadNotifications: Int
        if let userId = userId {
            unreadNotifications = self.notifications.filter { $0.userId == userId && !$0.isRead }.count
        } else {
            unreadNotifications = self.notifications.filter { !$0.isRead }.count
        }

        // Count unread documents (documents where readAt == nil, filter by userId if provided)
        // IMPORTANT: Only count documents that belong to the current user to avoid counting
        // mock documents or documents from other users
        let unreadDocuments: Int
        if let userId = userId {
            let userDocuments = self.documentService.getDocuments(for: userId)
            unreadDocuments = userDocuments.filter {
                $0.readAt == nil && !$0.isExcludedFromInvestorDocumentInbox
            }.count

            // Debug logging to help diagnose issues
            let allUnread = self.documentService.documents.filter { $0.readAt == nil }.count
            let totalCount = unreadNotifications + unreadDocuments
            print("🔔 NotificationService.getCombinedUnreadCount: userId=\(userId)")
            print("   📊 Unread notifications: \(unreadNotifications)")
            print("   📊 Unread documents (user): \(unreadDocuments)")
            print("   📊 Total unread documents (all users): \(allUnread)")
            print("   📊 Combined unread count: \(totalCount)")

            if unreadDocuments < allUnread {
                let otherUsersDocs = self.documentService.documents.filter { $0.readAt == nil && $0.userId != userId }
                print("   ⚠️ Found \(otherUsersDocs.count) unread documents from other users (not counted)")
                for doc in otherUsersDocs.prefix(3) {
                    print("      - \(doc.name.prefix(40))... (userId: '\(doc.userId)')")
                }
            }
        } else {
            unreadDocuments = self.documentService.documents.filter {
                $0.readAt == nil && !$0.isExcludedFromInvestorDocumentInbox
            }.count
        }

        return unreadNotifications + unreadDocuments
    }

    func getCombinedItems() -> [NotificationItem] {
        // Combine notifications and documents
        let notificationItems = self.notifications.map { NotificationItem.notification($0) }
        let documentItems = self.documentService.documents
            .filter { !$0.isExcludedFromInvestorDocumentInbox }
            .map { NotificationItem.document($0) }
        return notificationItems + documentItems
    }

    // MARK: - Push Token Management

    /// Configure PushTokenAPIService (called after initialization)
    func configure(pushTokenAPIService: PushTokenAPIServiceProtocol) {
        self.pushTokenAPIService = pushTokenAPIService
    }

    func registerPushToken(_ token: String, tokenType: PushTokenType, userId: String, deviceId: String?) async throws {
        guard let apiService = pushTokenAPIService else {
            print("⚠️ PushTokenAPIService not configured, skipping token registration")
            return
        }

        // Store token for sync
        self.currentPushToken = (token: token, type: tokenType, deviceId: deviceId)

        // Register token with backend (write-through pattern)
        do {
            _ = try await apiService.registerPushToken(token, tokenType: tokenType, userId: userId, deviceId: deviceId)
            print("✅ Push token registered on backend: \(token.prefix(20))...")
        } catch {
            print("⚠️ Failed to register push token on backend: \(error.localizedDescription)")
            throw error
        }
    }

    func deactivatePushToken(_ token: String, tokenType: PushTokenType, userId: String) async throws {
        guard let apiService = pushTokenAPIService else {
            print("⚠️ PushTokenAPIService not configured, skipping token deactivation")
            return
        }

        // Clear stored token
        if self.currentPushToken?.token == token && self.currentPushToken?.type == tokenType {
            self.currentPushToken = nil
        }

        // Deactivate token on backend (write-through pattern)
        do {
            try await apiService.deactivatePushToken(token, tokenType: tokenType, userId: userId)
            print("✅ Push token deactivated on backend: \(token.prefix(20))...")
        } catch {
            print("⚠️ Failed to deactivate push token on backend: \(error.localizedDescription)")
            throw error
        }
    }

    func syncPushTokensToBackend(for userId: String) async {
        guard let apiService = pushTokenAPIService else {
            print("⚠️ PushTokenAPIService not configured, skipping push token sync")
            return
        }

        // Sync current push token if available
        if let (token, type, deviceId) = currentPushToken {
            do {
                _ = try await apiService.registerPushToken(token, tokenType: type, userId: userId, deviceId: deviceId)
                print("✅ Push token synced to backend")
            } catch {
                print("⚠️ Failed to sync push token to backend: \(error.localizedDescription)")
            }
        } else {
            print("ℹ️ No push token to sync")
        }
    }
}
