import SwiftUI
import Combine

// MARK: - Investor-Specific Notifications View
struct NotificationsInvestorView: View {
    @Environment(\.appServices) private var appServices
    @State private var selectedFilter: NotificationFilter = .all
    @State private var showFilters = false

    // Investor-specific filters (no trades)
    private let availableFilters: [NotificationFilter] = [.all, .investments, .system]

    var body: some View {
        NotificationsInvestorContentView(
            appServices: appServices,
            selectedFilter: $selectedFilter,
            showFilters: $showFilters,
            availableFilters: availableFilters
        )
    }
}

// MARK: - Content View with Observable Notification Service
private struct NotificationsInvestorContentView: View {
    let appServices: AppServices
    @Binding var selectedFilter: NotificationFilter
    @Binding var showFilters: Bool
    let availableFilters: [NotificationFilter]

    private let notificationService: any NotificationServiceProtocol
    @State private var notifications: [AppNotification] = []
    @State private var cancellables = Set<AnyCancellable>()

    init(appServices: AppServices, selectedFilter: Binding<NotificationFilter>, showFilters: Binding<Bool>, availableFilters: [NotificationFilter]) {
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
                    filterHeader

                    // Notifications List
                    ScrollView {
                        LazyVStack(spacing: ResponsiveDesign.spacing(16)) {
                            ForEach(filteredNotifications) { notification in
                                NotificationCardView(
                                    notification: notification,
                                    notificationService: notificationService,
                                    userId: appServices.userService.currentUser?.id ?? "",
                                    customerSupportService: appServices.customerSupportService,
                                    satisfactionSurveyService: appServices.satisfactionSurveyService
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
            // Keep role-based view reactive without depending on concrete NotificationService.
            cancellables.removeAll()
            notifications = notificationService.notifications
            notificationService.notificationsPublisher
                .receive(on: DispatchQueue.main)
                .sink { newNotifications in
                    self.notifications = newNotifications
                }
                .store(in: &cancellables)
        }
        .onDisappear {
            cancellables.removeAll()
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
        let currentUserId = appServices.userService.currentUser?.id ?? ""
        let userNotifications = notifications.filter { $0.userId == currentUserId }

        switch selectedFilter {
        case .all:
            return userNotifications
        case .investments:
            return userNotifications.filter { $0.type == .investment }
        case .system:
            return userNotifications.filter { $0.type == .system }
        case .trades:
            return [] // No trades for investors
        case .documents:
            return [] // Documents are handled separately in the unified view
        }
    }

}

// MARK: - Investor-Specific Notification Card
struct InvestorNotificationCard: View {
    let notification: AppNotification
    @State private var isRead = false

    var body: some View {
        Button(action: { isRead = true }, label: {
            HStack(spacing: ResponsiveDesign.spacing(16)) {
                // Icon with investor-specific styling
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
                                .fill(AppTheme.accentGreen)
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
                                .foregroundColor(AppTheme.accentGreen)
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
        case .investment:
            return AppTheme.accentGreen
        case .system:
            return AppTheme.accentOrange
        case .trader:
            return AppTheme.accentLightBlue // Fallback, shouldn't occur for investors
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
    NotificationsInvestorView()
}
