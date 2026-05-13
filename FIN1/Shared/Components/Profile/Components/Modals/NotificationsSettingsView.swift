import SwiftUI

struct NotificationsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var appServices

    // Notification preferences
    @State private var pushNotificationsEnabled = true
    @State private var emailNotificationsEnabled = true
    @State private var investmentNotificationsEnabled = true
    @State private var tradeNotificationsEnabled = true
    @State private var systemNotificationsEnabled = true
    @State private var marketAlertsEnabled = true
    @State private var performanceUpdatesEnabled = true
    @State private var securityAlertsEnabled = true

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(24)) {
                        // Header
                        VStack(spacing: ResponsiveDesign.spacing(8)) {
                            Text("Notification Settings")
                                .font(ResponsiveDesign.headlineFont())
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.fontColor)

                            Text("Customize how you receive notifications")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, ResponsiveDesign.spacing(16))

                        // General Notification Settings
                        self.notificationSection(
                            title: "General",
                            icon: "bell.fill",
                            color: AppTheme.accentOrange
                        ) {
                            VStack(spacing: ResponsiveDesign.spacing(16)) {
                                NotificationToggleRow(
                                    title: "Push Notifications",
                                    subtitle: "Receive notifications on your device",
                                    isEnabled: self.$pushNotificationsEnabled
                                )

                                NotificationToggleRow(
                                    title: "Email Notifications",
                                    subtitle: "Receive notifications via email",
                                    isEnabled: self.$emailNotificationsEnabled
                                )
                            }
                        }

                        // Role-Specific Notifications
                        if self.appServices.userService.currentUser?.role == .investor {
                            self.notificationSection(
                                title: "Investment Notifications",
                                icon: "chart.pie.fill",
                                color: AppTheme.accentGreen
                            ) {
                                VStack(spacing: ResponsiveDesign.spacing(16)) {
                                    NotificationToggleRow(
                                        title: "Investment Updates",
                                        subtitle: "Investment changes and status",
                                        isEnabled: self.$investmentNotificationsEnabled
                                    )

                                    NotificationToggleRow(
                                        title: "Profit Distributions",
                                        subtitle: "When profits are distributed",
                                        isEnabled: self.$performanceUpdatesEnabled
                                    )

                                    NotificationToggleRow(
                                        title: "Risk Assessments",
                                        subtitle: "Investment risk updates",
                                        isEnabled: self.$securityAlertsEnabled
                                    )
                                }
                            }
                        } else {
                            self.notificationSection(
                                title: "Trading Notifications",
                                icon: "chart.line.uptrend.xyaxis",
                                color: AppTheme.accentLightBlue
                            ) {
                                VStack(spacing: ResponsiveDesign.spacing(16)) {
                                    NotificationToggleRow(
                                        title: "Trade Executions",
                                        subtitle: "When trades are completed",
                                        isEnabled: self.$tradeNotificationsEnabled
                                    )

                                    NotificationToggleRow(
                                        title: "Performance Updates",
                                        subtitle: "Trading performance metrics",
                                        isEnabled: self.$performanceUpdatesEnabled
                                    )

                                    NotificationToggleRow(
                                        title: "Market Alerts",
                                        subtitle: "Important market movements",
                                        isEnabled: self.$marketAlertsEnabled
                                    )
                                }
                            }
                        }

                        // System Notifications
                        self.notificationSection(
                            title: "System & Security",
                            icon: "gear",
                            color: AppTheme.accentRed
                        ) {
                            VStack(spacing: ResponsiveDesign.spacing(16)) {
                                NotificationToggleRow(
                                    title: "System Updates",
                                    subtitle: "App updates and maintenance",
                                    isEnabled: self.$systemNotificationsEnabled
                                )

                                NotificationToggleRow(
                                    title: "Security Alerts",
                                    subtitle: "Account security notifications",
                                    isEnabled: self.$securityAlertsEnabled
                                )
                            }
                        }

                        // Quick Actions
                        VStack(spacing: ResponsiveDesign.spacing(12)) {
                            Button(action: {
                                // Reset to defaults
                                self.resetToDefaults()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                        .font(ResponsiveDesign.bodyFont())
                                    Text("Reset to Defaults")
                                        .font(ResponsiveDesign.bodyFont())
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(AppTheme.accentLightBlue)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(AppTheme.sectionBackground)
                                .cornerRadius(ResponsiveDesign.spacing(8))
                            }

                            Button(action: {
                                // Test notifications
                                self.testNotifications()
                            }) {
                                HStack {
                                    Image(systemName: "bell.badge")
                                        .font(ResponsiveDesign.bodyFont())
                                    Text("Test Notifications")
                                        .font(ResponsiveDesign.bodyFont())
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(AppTheme.accentGreen)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(AppTheme.sectionBackground)
                                .cornerRadius(ResponsiveDesign.spacing(8))
                            }
                        }
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(16))
                    .padding(.bottom, ResponsiveDesign.spacing(16))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        self.dismiss()
                    }
                    .foregroundColor(AppTheme.fontColor)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        self.saveSettings()
                        self.dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func notificationSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            HStack {
                Image(systemName: icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(color)
                    .frame(width: 24)

                Text(title)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                Spacer()
            }

            content()
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private func resetToDefaults() {
        self.pushNotificationsEnabled = true
        self.emailNotificationsEnabled = true
        self.investmentNotificationsEnabled = true
        self.tradeNotificationsEnabled = true
        self.systemNotificationsEnabled = true
        self.marketAlertsEnabled = true
        self.performanceUpdatesEnabled = true
        self.securityAlertsEnabled = true
    }

    func testNotifications() {
        // TODO: Implement test notification functionality
        print("Testing notifications...")
    }

    private func saveSettings() {
        // TODO: Save notification preferences to UserDefaults or backend
        print("Saving notification settings...")
    }
}

// MARK: - Notification Toggle Row
struct NotificationToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text(self.title)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Text(self.subtitle)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }

            Spacer()

            Toggle("", isOn: self.$isEnabled)
                .toggleStyle(SwitchToggleStyle(tint: AppTheme.accentLightBlue))
        }
    }
}

#Preview {
    NotificationsSettingsView()
}
