import Combine
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
            appServices: self.appServices,
            selectedFilter: self.$selectedFilter,
            showFilters: self.$showFilters,
            availableFilters: self.availableFilters
        )
    }
}

// MARK: - Content View with Observable Notification Service
private struct NotificationsTraderContentView: View {
    let appServices: AppServices
    @Binding var selectedFilter: NotificationFilter
    @Binding var showFilters: Bool
    let availableFilters: [NotificationFilter]

    private let notificationService: any NotificationServiceProtocol
    @State private var notifications: [AppNotification] = []
    @State private var cancellables = Set<AnyCancellable>()

    init(
        appServices: AppServices,
        selectedFilter: Binding<NotificationFilter>,
        showFilters: Binding<Bool>,
        availableFilters: [NotificationFilter]
    ) {
        self.appServices = appServices
        _selectedFilter = selectedFilter
        _showFilters = showFilters
        self.availableFilters = availableFilters

        self.notificationService = appServices.notificationService
        self._notifications = State(initialValue: appServices.notificationService.notifications)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: ResponsiveDesign.spacing(0)) {
                    // Filter Header
                    self.filterHeader

                    // Notifications List
                    ScrollView {
                        LazyVStack(spacing: ResponsiveDesign.spacing(16)) {
                            ForEach(self.filteredNotifications) { notification in
                                NotificationCardView(
                                    notification: notification,
                                    notificationService: self.notificationService,
                                    userId: self.appServices.userService.currentUser?.id ?? "",
                                    customerSupportService: self.appServices.customerSupportService,
                                    satisfactionSurveyService: self.appServices.satisfactionSurveyService,
                                    documentService: self.appServices.documentService
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
                    Button(action: { self.showFilters = true }, label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(AppTheme.accentLightBlue)
                    })
                }
            })
        }
        .navigationDestination(for: Document.self) { document in
            DocumentNavigationHelper.navigationDestination(for: document, appServices: self.appServices)
        }
        .sheet(isPresented: self.$showFilters) {
            NotificationFilterView(selectedFilter: self.$selectedFilter, availableFilters: self.availableFilters)
        }
        .onAppear {
            self.selectedFilter = .all
            // Keep role-based view reactive without depending on concrete NotificationService.
            self.cancellables.removeAll()
            self.notifications = self.notificationService.notifications
            self.notificationService.notificationsPublisher
                .receive(on: DispatchQueue.main)
                .sink { newNotifications in
                    self.notifications = newNotifications
                }
                .store(in: &self.cancellables)
        }
        .onDisappear {
            self.cancellables.removeAll()
        }
    }

    private var filterHeader: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            // Quick Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    ForEach(self.availableFilters, id: \.self) { filter in
                        NotificationFilterPill(
                            title: filter.displayName,
                            isSelected: self.selectedFilter == filter
                        ) {
                            self.selectedFilter = filter
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
        let currentUserId = self.appServices.userService.currentUser?.id ?? ""
        let allNotifications = self.notifications
        let userNotifications = allNotifications.filter { $0.userId == currentUserId }

        switch self.selectedFilter {
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
        Button(action: { self.isRead = true }, label: {
            HStack(spacing: ResponsiveDesign.spacing(16)) {
                // Icon with trader-specific styling
                Circle()
                    .fill(self.notificationColor.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: self.notification.type.icon)
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(self.notificationColor)
                    )

                // Content
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    HStack {
                        Text(self.notification.title)
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        if !self.isRead {
                            Circle()
                                .fill(AppTheme.accentLightBlue)
                                .frame(width: 8, height: 8)
                        }
                    }

                    Text(self.notification.message)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.8))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    HStack {
                        Text(self.notification.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.6))

                        Spacer()

                        if self.notification.priority == .high || self.notification.priority == .urgent {
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
            .opacity(self.isRead ? 0.7 : 1.0)
        })
        .buttonStyle(PlainButtonStyle())
    }

    private var notificationColor: Color {
        switch self.notification.type {
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
