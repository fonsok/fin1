import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var appServices
    @State private var selectedFilter: NotificationFilter = .all
    @State private var showDocumentArchive = false

    // Observe the notification service to react to changes
    @StateObject private var notificationServiceWrapper = NotificationServiceObserver()

    private var notificationService: NotificationService {
        notificationServiceWrapper.service
    }

    // Initialize filter based on user role
    private var initialFilter: NotificationFilter {
        switch appServices.userService.currentUser?.role {
        case .investor:
            return .investments
        case .trader:
            return .trades
        default:
            return .all
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: ResponsiveDesign.spacing(0)) {
                    // Title
                    Text("Notifications")
                        .font(ResponsiveDesign.titleFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)
                        .padding(.top, ResponsiveDesign.spacing(16))
                        .padding(.bottom, ResponsiveDesign.spacing(8))

                    // Filter Tabs
                    filterTabs

                    // Notifications List
                    notificationsList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Set initial filter based on user role
                selectedFilter = initialFilter
                // Update the observer with the service from appServices
                if let service = appServices.notificationService as? NotificationService {
                    notificationServiceWrapper.service = service
                    print("✅ NotificationsView: Using notification service from appServices")
                    print("   🔍 NotificationService instance: \(ObjectIdentifier(service))")
                    print("   🔍 AppServices.live.notificationService instance: \(ObjectIdentifier(AppServices.live.notificationService as? NotificationService ?? NotificationService.shared))")
                    print("   📊 Total notifications: \(service.notifications.count)")
                    let currentUserId = appServices.userService.currentUser?.id ?? ""
                    let userNotifications = service.notifications.filter { $0.userId == currentUserId }
                    print("   📊 User '\(currentUserId)' notifications: \(userNotifications.count)")

                    // Debug: Check if this is the same instance as AppServices.live
                    if let liveService = AppServices.live.notificationService as? NotificationService,
                       ObjectIdentifier(service) == ObjectIdentifier(liveService) {
                        print("   ✅ Same instance as AppServices.live")
                    } else {
                        print("   ⚠️ DIFFERENT instance from AppServices.live!")
                    }
                } else {
                    print("⚠️ NotificationsView: Failed to cast notificationService to NotificationService")
                }
            }
            .sheet(isPresented: $showDocumentArchive) {
                DocumentArchiveView()
            }
            .navigationDestination(for: Document.self) { document in
                DocumentNavigationHelper.navigationDestination(for: document, appServices: appServices)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.fontColor)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        markAllAsRead()
                    }) {
                        Text("Mark All Read")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.accentLightBlue)
                    }
                }
            }
        }
    }

    // MARK: - Combined Items (Notifications + Documents)
    private var combinedItems: [NotificationItem] {
        // Filter notifications by current user's userId to prevent showing other users' notifications
        // Access notifications directly from observed service to trigger view updates
        let currentUserId = appServices.userService.currentUser?.id ?? ""
        let allNotifications = notificationService.notifications
        let userNotifications = allNotifications.filter { $0.userId == currentUserId }
        let notificationItems = userNotifications.map { NotificationItem.notification($0) }
        // Filter documents by current user's userId to prevent showing other users' documents
        let userDocuments = appServices.documentService.getDocuments(for: currentUserId)
        let documentItems = userDocuments.map { NotificationItem.document($0) }
        return notificationItems + documentItems
    }

    // MARK: - Filter Tabs
    private var filterTabs: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            ForEach(availableFilters, id: \.self) { filter in
                Button(action: {
                    selectedFilter = filter
                }) {
                    Text(filter.displayName)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(selectedFilter == filter ? AppTheme.screenBackground : AppTheme.fontColor)
                        .padding(.horizontal, ResponsiveDesign.spacing(16))
                        .padding(.vertical, ResponsiveDesign.spacing(8))
                        .background(selectedFilter == filter ? AppTheme.accentLightBlue : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(20))
                                .stroke(AppTheme.accentLightBlue, lineWidth: 1)
                        )
                        .cornerRadius(ResponsiveDesign.spacing(20))
                }
            }
        }
        .padding(.horizontal, ResponsiveDesign.spacing(16))
        .padding(.vertical, ResponsiveDesign.spacing(12))
    }

    // MARK: - Available Filters (Role-based)
    private var availableFilters: [NotificationFilter] {
        switch appServices.userService.currentUser?.role {
        case .investor:
            return [.all, .system, .documents]
        case .trader:
            return [.all, .system, .documents]
        default:
            return NotificationFilter.allCases
        }
    }

    // MARK: - Notifications List
    private var notificationsList: some View {
        ScrollView {
            LazyVStack(spacing: ResponsiveDesign.spacing(12)) {
                // Info banner about automatic archiving
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.accentLightBlue)

                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                        Text("Automatic Archiving")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)

                        Text("Read notifications are automatically moved to archive after 24 hours")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()
                }
                .padding(ResponsiveDesign.spacing(16))
                .background(AppTheme.accentLightBlue.opacity(0.1))
                .cornerRadius(ResponsiveDesign.spacing(12))

                ForEach(filteredItems) { item in
                    UnifiedItemCard(item: item, notificationService: notificationService)
                }

                // Info about automatic cleanup
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.accentLightBlue)

                        Text("Read notifications are automatically archived after 24 hours")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))

                        Spacer()
                    }

                    // Archive button for older notifications
                    if hasHiddenOlderNotifications {
                        Button(action: {
                            showDocumentArchive = true
                        }) {
                            HStack {
                                Image(systemName: "archivebox")
                                    .font(ResponsiveDesign.captionFont())

                                Text("View Archived Documents")
                                    .font(ResponsiveDesign.captionFont())
                                    .fontWeight(.medium)

                                Spacer()

                                Text("\(getArchivedCount())")
                                    .font(ResponsiveDesign.captionFont())
                                    .padding(.horizontal, ResponsiveDesign.spacing(6))
                                    .padding(.vertical, ResponsiveDesign.spacing(2))
                                    .background(AppTheme.accentLightBlue.opacity(0.2))
                                    .cornerRadius(ResponsiveDesign.spacing(4))
                            }
                            .foregroundColor(AppTheme.accentLightBlue)
                            .padding(.horizontal, ResponsiveDesign.spacing(12))
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                            .background(AppTheme.sectionBackground)
                            .cornerRadius(ResponsiveDesign.spacing(8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, ResponsiveDesign.spacing(16))
                .padding(.vertical, ResponsiveDesign.spacing(8))
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(8))
            }
            .padding(.horizontal, ResponsiveDesign.spacing(16))
            .padding(.bottom, ResponsiveDesign.spacing(16))
        }
    }

    // MARK: - Check for Hidden Items
    private var hasHiddenOlderNotifications: Bool {
        let allItems = combinedItems
        let recentItems = allItems.filter { item in
            !item.isRead ||
            (item.isRead && getReadAt(for: item) != nil &&
             (getReadAt(for: item) ?? Date.distantPast) > Date().addingTimeInterval(-86400))
        }
        return allItems.count > recentItems.count
    }

    // MARK: - Get Archived Count
    private func getArchivedCount() -> Int {
        let allItems = combinedItems
        let recentItems = allItems.filter { item in
            !item.isRead ||
            (item.isRead && getReadAt(for: item) != nil &&
             (getReadAt(for: item) ?? Date.distantPast) > Date().addingTimeInterval(-86400))
        }
        return allItems.count - recentItems.count
    }

    // MARK: - Mark All as Read
    private func markAllAsRead() {
        appServices.notificationService.markAllAsRead()
        // Access document service via environment in subviews; if needed, lift an env object here.
    }

    // MARK: - Filtered Items (Notifications + Documents)
    private var filteredItems: [NotificationItem] {
        let allItems = combinedItems

        // Smart cleanup: Keep unread + recent read items (24 hours after being read)
        let recentItems = allItems.filter { item in
            !item.isRead ||
            (item.isRead && getReadAt(for: item) != nil &&
             (getReadAt(for: item) ?? Date.distantPast) > Date().addingTimeInterval(-86400))
        }

        switch selectedFilter {
        case .all:
            return recentItems
        case .investments:
            return recentItems.filter { item in
                if case .notification(let notification) = item {
                    return notification.type == .investment
                }
                return false
            }
        case .trades:
            return recentItems.filter { item in
                if case .notification(let notification) = item {
                    return notification.type == .trader
                }
                return false
            }
        case .system:
            return recentItems.filter { item in
                if case .notification(let notification) = item {
                    return notification.type == .system
                }
                return false
            }
        case .documents:
            return recentItems.filter { item in
                if case .document = item {
                    return true
                }
                return false
            }

        }
    }

    // MARK: - Helper Functions
    private func getReadAt(for item: NotificationItem) -> Date? {
        switch item {
        case .notification(let notification):
            return notification.isRead ? Date.distantPast : nil
        case .document(let document):
            return document.readAt
        }
    }
}

// MARK: - Notification Service Observer
/// Wrapper to observe NotificationService changes
@MainActor
class NotificationServiceObserver: ObservableObject {
    @Published var service: NotificationService

    init(service: NotificationService = NotificationService.shared) {
        self.service = service
    }
}

#Preview {
    NotificationsView()
}
