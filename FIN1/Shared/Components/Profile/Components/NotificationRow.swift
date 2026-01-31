import SwiftUI

struct NotificationRow: View {
    let notification: AppNotification
    @State private var isRead: Bool
    @Environment(\.appServices) private var appServices

    init(notification: AppNotification) {
        self.notification = notification
        self._isRead = State(initialValue: !notification.isRead)
    }

    var body: some View {
        Button(action: {
            isRead = true
            appServices.notificationService.markAsRead(notification)
        }) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                // Icon
                Circle()
                    .fill(notificationColor.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: notification.type.icon)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(notificationColor)
                    )

                // Content
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    HStack {
                        Text(notification.title)
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)
                            .lineLimit(1)

                        Spacer()

                        if !isRead {
                            Circle()
                                .fill(AppTheme.accentLightBlue)
                                .frame(width: 6, height: 6)
                        }
                    }

                    Text(notification.message)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(notification.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))
                }

                Spacer()
            }
            .padding(ResponsiveDesign.spacing(12))
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
            .opacity(isRead ? 0.7 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var notificationColor: Color {
        switch notification.type {
        case .investment:
            return AppTheme.accentGreen
        case .trader:
            return AppTheme.accentLightBlue
        case .system:
            return AppTheme.accentOrange
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
    VStack(spacing: ResponsiveDesign.spacing(12)) {
        NotificationRow(notification: AppNotification(
            userId: "user1",
            title: "Investment Completed",
            message: "Your investment in John Smith has been completed successfully. Total return: +$250",
            type: .investment,
            priority: .medium,
            isRead: false,
            createdAt: Date().addingTimeInterval(-3600)
        ))
        NotificationRow(notification: AppNotification(
            userId: "user1",
            title: "Profit Distribution",
            message: "Profit distribution of $180 has been credited to your account",
            type: .investment,
            priority: .medium,
            isRead: true,
            createdAt: Date().addingTimeInterval(-86400)
        ))
    }
    .padding()
    .background(AppTheme.screenBackground)
}
