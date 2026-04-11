import SwiftUI

// MARK: - Shared Notification Types
// NotificationType is now defined in Shared/Models/Notification.swift

// MARK: - Notification Filter Enum
enum NotificationFilter: String, CaseIterable {
    case all = "All"
    case investments = "Investments"
    case trades = "Trades"
    case system = "System"
    case documents = "Documents"

    var displayName: String { rawValue }
}

// MARK: - Shared Notification Components
struct NotificationFilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action, label: {
            Text(title)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.medium)
                .foregroundColor(isSelected ? AppTheme.screenBackground : AppTheme.accentLightBlue)
                .padding(.horizontal, ResponsiveDesign.spacing(16))
                .padding(.vertical, ResponsiveDesign.spacing(8))
                .background(isSelected ? AppTheme.accentLightBlue : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(20))
                        .stroke(AppTheme.accentLightBlue, lineWidth: 1)
                )
                .cornerRadius(ResponsiveDesign.spacing(20))
        })
    }
}

struct NotificationFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFilter: NotificationFilter
    let availableFilters: [NotificationFilter]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: ResponsiveDesign.spacing(24)) {
                    Text("Filter Notifications")
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)

                    VStack(spacing: ResponsiveDesign.spacing(16)) {
                        ForEach(availableFilters, id: \.self) { filter in
                            Button(action: {
                                selectedFilter = filter
                                dismiss()
                            }) {
                                HStack {
                                    Text(filter.displayName)
                                        .font(ResponsiveDesign.headlineFont())
                                        .foregroundColor(selectedFilter == filter ? AppTheme.screenBackground : AppTheme.fontColor)
                                    Spacer()
                                    if selectedFilter == filter {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppTheme.screenBackground)
                                    }
                                }
                                .responsivePadding()
                                .background(selectedFilter == filter ? AppTheme.accentLightBlue : AppTheme.inputFieldBackground)
                                .cornerRadius(ResponsiveDesign.spacing(12))
                            }
                        }
                    }

                    Spacer()
                }
                .responsivePadding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            })
        }
    }
}

// MARK: - Shared Mock Data
struct MockNotification: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let type: NotificationType
    let icon: String
    let timestamp: Date
    let hasAction: Bool
    var isRead: Bool = false
    var readAt: Date?  // When the notification was marked as read
}

// MARK: - Role-Specific Mock Data
let mockInvestorNotifications = [
    MockNotification(
        title: "Investment Completed",
        message: "Your investment in Jan Becker has been completed successfully. Total return: +250 €",
        type: .investment,
        icon: "checkmark.circle.fill",
        timestamp: Date().addingTimeInterval(-3600),
        hasAction: true,
        isRead: false
    ),
    MockNotification(
        title: "Profit Distribution",
        message: "Profit distribution of $180 has been credited to your account",
        type: .investment,
        icon: "dollarsign.circle.fill",
        timestamp: Date().addingTimeInterval(-86400),
        hasAction: true,
        isRead: false
    ),
    MockNotification(
        title: "New Trader Available",
        message: "Tobias Hoffmann is now accepting new investments. Specialization: Bonus-Zertifikate",
        type: .investment,
        icon: "person.badge.plus.fill",
        timestamp: Date().addingTimeInterval(-259200),
        hasAction: true,
        isRead: false
    ),
    MockNotification(
        title: "System Maintenance",
        message: "Scheduled maintenance will occur tonight from 2:00 AM to 4:00 AM EST",
        type: .system,
        icon: "wrench.and.screwdriver.fill",
        timestamp: Date().addingTimeInterval(-172800),
        hasAction: false,
        isRead: true
    )
]

let mockTraderNotifications = [
    AppNotification(
        userId: "trader1",
        title: "Trade Executed",
        message: "AAPL buy order executed: 10 shares @ $175.43",
        type: .trader,
        priority: .medium,
        isRead: false,
        createdAt: Date().addingTimeInterval(-7200)
    ),
    AppNotification(
        userId: "trader1",
        title: "Trade Alert",
        message: "TSLA has reached your target price of $245. Consider closing your position",
        type: .trader,
        priority: .high,
        isRead: false,
        createdAt: Date().addingTimeInterval(-345600)
    ),
    AppNotification(
        userId: "trader1",
        title: "System Maintenance",
        message: "Scheduled maintenance will occur tonight from 2:00 AM to 4:00 AM EST",
        type: .system,
        priority: .low,
        isRead: true,
        createdAt: Date().addingTimeInterval(-172800)
    )
]
