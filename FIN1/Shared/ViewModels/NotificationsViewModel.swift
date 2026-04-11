import Foundation
import SwiftUI
import Combine

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var selectedFilter: NotificationFilter = .all {
        didSet { recompute() }
    }
    @Published var showDocumentArchive = false

    @Published private(set) var filteredItems: [NotificationItem] = []
    @Published private(set) var archivedItems: [NotificationItem] = []
    @Published private(set) var hasHiddenOlderItems = false
    @Published private(set) var archivedCount = 0

    private let notificationService: any NotificationServiceProtocol
    private let documentService: any DocumentServiceProtocol
    private let userService: any UserServiceProtocol

    private var cancellables = Set<AnyCancellable>()

    private let recentReadWindow: TimeInterval = 86_400 // 24h

    init(
        notificationService: any NotificationServiceProtocol,
        documentService: any DocumentServiceProtocol,
        userService: any UserServiceProtocol
    ) {
        self.notificationService = notificationService
        self.documentService = documentService
        self.userService = userService

        setupObservations()
        applyRoleDefaultFilterIfNeeded()
        recompute()
    }

    func applyRoleDefaultFilterIfNeeded() {
        guard selectedFilter == .all else { return }
        switch userService.currentUser?.role {
        case .investor:
            selectedFilter = .investments
        case .trader:
            selectedFilter = .trades
        default:
            selectedFilter = .all
        }
    }

    func availableFilters() -> [NotificationFilter] {
        switch userService.currentUser?.role {
        case .investor:
            return [.all, .system, .documents]
        case .trader:
            return [.all, .system, .documents]
        default:
            return NotificationFilter.allCases
        }
    }

    func markAllAsRead() {
        notificationService.markAllAsRead()
    }

    private func setupObservations() {
        notificationService.notificationsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recompute()
            }
            .store(in: &cancellables)

        documentService.documentsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recompute()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .userDidSignIn)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyRoleDefaultFilterIfNeeded()
                self?.recompute()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .userDataDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recompute()
            }
            .store(in: &cancellables)
    }

    // MARK: - Recompute

    private func recompute() {
        let allItems = combinedItemsForCurrentUser()
        let recentItems = applyRecentReadWindow(to: allItems)
        filteredItems = applyFilter(selectedFilter, to: recentItems)

        let archivedBaseItems = applyArchivedReadWindow(to: allItems)
        archivedItems = applyFilter(selectedFilter, to: archivedBaseItems)

        hasHiddenOlderItems = !archivedItems.isEmpty
        archivedCount = archivedItems.count
    }

    private func combinedItemsForCurrentUser() -> [NotificationItem] {
        let currentUserId = userService.currentUser?.id ?? ""
        let userNotifications = notificationService.notifications.filter { $0.userId == currentUserId }
        let notificationItems = userNotifications.map { NotificationItem.notification($0) }

        let userDocuments = documentService.getDocuments(for: currentUserId)
        let documentItems = userDocuments.map { NotificationItem.document($0) }

        return notificationItems + documentItems
    }

    private func applyRecentReadWindow(to items: [NotificationItem]) -> [NotificationItem] {
        let cutoff = Date().addingTimeInterval(-recentReadWindow)
        return items.filter { item in
            !item.isRead || (readAt(for: item) ?? Date.distantPast) > cutoff
        }
    }

    private func applyArchivedReadWindow(to items: [NotificationItem]) -> [NotificationItem] {
        let cutoff = Date().addingTimeInterval(-recentReadWindow)
        // Archived = read items older than the recent window.
        return items.filter { item in
            guard item.isRead else { return false }
            return (readAt(for: item) ?? Date.distantPast) <= cutoff
        }
    }

    private func applyFilter(_ filter: NotificationFilter, to items: [NotificationItem]) -> [NotificationItem] {
        switch filter {
        case .all:
            return items
        case .investments:
            return items.filter { item in
                if case .notification(let n) = item {
                    return n.type == .investment
                }
                return false
            }
        case .trades:
            return items.filter { item in
                if case .notification(let n) = item {
                    return n.type == .trader
                }
                return false
            }
        case .system:
            return items.filter { item in
                if case .notification(let n) = item {
                    // Keep support notifications visible in `.all`, but don't mix them into the System filter.
                    if n.serverCategory?.lowercased() == "support" { return false }
                    if case .ticket = NotificationMetadataActionResolver.resolve(for: n) { return false }
                    return n.type == .system
                }
                return false
            }
        case .documents:
            return items.filter { item in
                if case .document = item { return true }
                return false
            }
        }
    }

    private func readAt(for item: NotificationItem) -> Date? {
        switch item {
        case .notification(let notification):
            return notification.readAt
        case .document(let document):
            return document.readAt
        }
    }
}

