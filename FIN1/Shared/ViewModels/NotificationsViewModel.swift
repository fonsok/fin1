import Combine
import Foundation
import SwiftUI

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var selectedFilter: NotificationFilter = .all {
        didSet { self.recompute() }
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

        self.setupObservations()
        self.applyRoleDefaultFilterIfNeeded()
        self.recompute()
    }

    func applyRoleDefaultFilterIfNeeded() {
        guard self.selectedFilter == .all else { return }
        switch self.userService.currentUser?.role {
        case .investor:
            self.selectedFilter = .investments
        case .trader:
            self.selectedFilter = .trades
        default:
            self.selectedFilter = .all
        }
    }

    func availableFilters() -> [NotificationFilter] {
        switch self.userService.currentUser?.role {
        case .investor:
            return [.all, .investments, .system, .documents]
        case .trader:
            return [.all, .trades, .system, .documents]
        default:
            return NotificationFilter.allCases
        }
    }

    func markAllAsRead() {
        self.notificationService.markAllAsRead()
    }

    private func setupObservations() {
        self.notificationService.notificationsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recompute()
            }
            .store(in: &self.cancellables)

        self.documentService.documentsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recompute()
            }
            .store(in: &self.cancellables)

        NotificationCenter.default.publisher(for: .userDidSignIn)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyRoleDefaultFilterIfNeeded()
                self?.recompute()
            }
            .store(in: &self.cancellables)

        NotificationCenter.default.publisher(for: .userDataDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recompute()
            }
            .store(in: &self.cancellables)

        NotificationCenter.default.publisher(for: .invoiceDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recompute()
            }
            .store(in: &self.cancellables)
    }

    // MARK: - Recompute

    private func recompute() {
        let allItems = self.combinedItemsForCurrentUser()
        let recentItems = self.applyRecentReadWindow(to: allItems)
        self.filteredItems = self.applyFilter(self.selectedFilter, to: recentItems)

        let archivedBaseItems = self.applyArchivedReadWindow(to: allItems)
        self.archivedItems = self.applyFilter(self.selectedFilter, to: archivedBaseItems)

        self.hasHiddenOlderItems = !self.archivedItems.isEmpty
        self.archivedCount = self.archivedItems.count
    }

    private func combinedItemsForCurrentUser() -> [NotificationItem] {
        let currentUserId = self.userService.currentUser?.id ?? ""
        let stableUserId = self.resolvedStableUserId()
        let allowedUserIds = Set([currentUserId, stableUserId].filter { !$0.isEmpty })

        let userNotifications = self.notificationService.notifications.filter { allowedUserIds.contains($0.userId) }
        let notificationItems = userNotifications.map { NotificationItem.notification($0) }

        let userDocuments = allowedUserIds
            .flatMap { self.documentService.getDocuments(for: $0) }
            .filter { self.isDisplayableNotificationDocument($0) }
            .uniqueById()
        let documentItems = userDocuments.map { NotificationItem.document($0) }

        return notificationItems + documentItems
    }

    private func resolvedStableUserId() -> String {
        guard let email = userService.currentUser?.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !email.isEmpty else {
            return ""
        }
        return "user:\(email)"
    }

    private func isDisplayableNotificationDocument(_ document: Document) -> Bool {
        if document.isExcludedFromInvestorDocumentInbox {
            return false
        }
        // Hide backend wallet receipts (IAR/IRR/IFR) from the Documents tab.
        // These are booking receipts, not user-facing collection-bill/invoice artifacts.
        if document.type == .financial {
            let accNo = (document.accountingDocumentNumber ?? "").uppercased()
            if accNo.hasPrefix("IAR-") || accNo.hasPrefix("IRR-") || accNo.hasPrefix("IFR-") {
                return false
            }
            if document.name.lowercased().hasPrefix("investorcollectionbill_") {
                return false
            }
        }
        return true
    }

    private func applyRecentReadWindow(to items: [NotificationItem]) -> [NotificationItem] {
        let cutoff = Date().addingTimeInterval(-self.recentReadWindow)
        return items.filter { item in
            !item.isRead || (self.readAt(for: item) ?? Date.distantPast) > cutoff
        }
    }

    private func applyArchivedReadWindow(to items: [NotificationItem]) -> [NotificationItem] {
        let cutoff = Date().addingTimeInterval(-self.recentReadWindow)
        // Archived = read items older than the recent window.
        return items.filter { item in
            guard item.isRead else { return false }
            return (self.readAt(for: item) ?? Date.distantPast) <= cutoff
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

private extension Array where Element == Document {
    func uniqueById() -> [Document] {
        var seen = Set<String>()
        return filter { seen.insert($0.id).inserted }
    }
}

