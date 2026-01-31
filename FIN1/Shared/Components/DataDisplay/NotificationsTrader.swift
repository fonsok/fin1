import SwiftUI

// MARK: - Trader-Specific Notifications View
struct NotificationsTraderView: View {
    @Environment(\.appServices) private var appServices
    @State private var selectedFilter: NotificationFilter = .all
    @State private var showFilters = false

    // Trader-specific filters (no investments)
    private let availableFilters: [NotificationFilter] = [.all, .trades, .system]

    var body: some View {
        NotificationsTraderContentView(
            appServices: appServices,
            selectedFilter: $selectedFilter,
            showFilters: $showFilters,
            availableFilters: availableFilters
        )
    }
}

// MARK: - Content View with Observable Notification Service
private struct NotificationsTraderContentView: View {
    let appServices: AppServices
    @Binding var selectedFilter: NotificationFilter
    @Binding var showFilters: Bool
    let availableFilters: [NotificationFilter]

    // Observe the notification service to react to changes
    @ObservedObject private var notificationService: NotificationService

    init(appServices: AppServices, selectedFilter: Binding<NotificationFilter>, showFilters: Binding<Bool>, availableFilters: [NotificationFilter]) {
        self.appServices = appServices
        _selectedFilter = selectedFilter
        _showFilters = showFilters
        self.availableFilters = availableFilters

        // Get the notification service from appServices and observe it
        // CRITICAL: Must use the same instance that CustomerSupportService uses
        guard let service = appServices.notificationService as? NotificationService else {
            print("⚠️ NotificationsTraderView: Failed to cast notificationService to NotificationService, using shared")
            _notificationService = ObservedObject(wrappedValue: NotificationService.shared)
            return
        }

        print("✅ NotificationsTraderView: Using notification service from appServices with \(service.notifications.count) notifications")
        _notificationService = ObservedObject(wrappedValue: service)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: ResponsiveDesign.spacing(0)) {
                    // Filter Header
                    filterHeader

                    // Notifications List
                    ScrollView {
                        LazyVStack(spacing: ResponsiveDesign.spacing(16)) {
                            ForEach(filteredNotifications) { notification in
                                NotificationCardView(
                                    notification: notification,
                                    notificationService: notificationService
                                )
                            }
                        }
                        .padding(.horizontal, ResponsiveDesign.spacing(16))
                        .padding(.top, ResponsiveDesign.spacing(16))
                        .padding(.bottom, ResponsiveDesign.spacing(16))
                        .scrollSection()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Notifications")
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showFilters = true }, label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(AppTheme.accentLightBlue)
                    })
                }
            })
        }
        .navigationDestination(for: Document.self) { document in
            DocumentNavigationHelper.navigationDestination(for: document, appServices: appServices)
        }
        .sheet(isPresented: $showFilters) {
            NotificationFilterView(selectedFilter: $selectedFilter, availableFilters: availableFilters)
        }
        .onAppear {
            selectedFilter = .all
        }
    }

    private var filterHeader: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            // Quick Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    ForEach(availableFilters, id: \.self) { filter in
                        NotificationFilterPill(
                            title: filter.displayName,
                            isSelected: selectedFilter == filter
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal, ResponsiveDesign.spacing(16))
            }
        }
        .padding(.top, ResponsiveDesign.spacing(16))
        .background(AppTheme.screenBackground)
    }

    private var filteredNotifications: [AppNotification] {
        // Filter notifications by current user's ID
        // Access notifications directly from observed service to trigger view updates
        let currentUserId = appServices.userService.currentUser?.id ?? ""
        let allNotifications = notificationService.notifications
        let userNotifications = allNotifications.filter { $0.userId == currentUserId }

        // Debug logging
        if !allNotifications.isEmpty {
            print("🔔 NotificationsTraderView: Total notifications: \(allNotifications.count), User notifications: \(userNotifications.count) for userId: \(currentUserId)")
            for notif in allNotifications.prefix(3) {
                print("   - Notification userId: '\(notif.userId)', title: '\(notif.title)'")
            }
        }

        switch selectedFilter {
        case .all:
            return userNotifications
        case .trades:
            return userNotifications.filter { $0.type == NotificationType.trader }
        case .system:
            return userNotifications.filter { $0.type == NotificationType.system }
        case .investments:
            return [] // No investments for traders
        case .documents:
            return [] // Documents are handled separately in the unified view
        }
    }

}

// MARK: - Trader-Specific Notification Card
struct TraderNotificationCard: View {
    let notification: AppNotification
    @State private var isRead = false

    var body: some View {
        Button(action: { isRead = true }, label: {
            HStack(spacing: ResponsiveDesign.spacing(16)) {
                // Icon with trader-specific styling
                Circle()
                    .fill(notificationColor.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: notification.type.icon)
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(notificationColor)
                    )

                // Content
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    HStack {
                        Text(notification.title)
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        if !isRead {
                            Circle()
                                .fill(AppTheme.accentLightBlue)
                                .frame(width: 8, height: 8)
                        }
                    }

                    Text(notification.message)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.8))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    HStack {
                        Text(notification.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.6))

                        Spacer()

                        if notification.priority == .high || notification.priority == .urgent {
                            Text("Tap to view")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.accentLightBlue)
                        }
                    }
                }
            }
            .padding(ResponsiveDesign.spacing(16))
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(16))
            .opacity(isRead ? 0.7 : 1.0)
        })
        .buttonStyle(PlainButtonStyle())
    }

    private var notificationColor: Color {
        switch notification.type {
        case .trader:
            return AppTheme.accentLightBlue
        case .system:
            return AppTheme.accentOrange
        case .investment:
            return AppTheme.accentGreen // Fallback, shouldn't occur for traders
        case .document:
            return AppTheme.accentOrange
        case .security:
            return AppTheme.accentRed
        case .marketing:
            return AppTheme.accentLightBlue
        }
    }
}

#Preview {
    NotificationsTraderView()
}
