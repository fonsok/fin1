import SwiftUI
import Combine

struct DashboardWelcomeHeader: View {
    @Environment(\.appServices) private var appServices
    @State private var logoutTimeRemaining: TimeInterval = 30 * 60 // 30 minutes in seconds
    @State private var timer: Timer?
    @State private var showLogoutWarning: Bool = false
    @Environment(\.themeManager) private var themeManager
    @State private var currentUser: User? // Local state to track user changes

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    // Combined "Welcome back," and full name on single line
                    HStack(spacing: ResponsiveDesign.spacing(4)) {
                        Text("Welcome back,")
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(AppTheme.secondaryText)

                        Text(currentUser?.fullName ?? "User")
                            .font(ResponsiveDesign.headlineFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)
                    }

                    // Username on separate line
                    if let username = currentUser?.username, !username.isEmpty {
                        HStack(spacing: ResponsiveDesign.spacing(4)) {
                            Text("Username:")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.tertiaryText)

                            Text(username)
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.tertiaryText)
                        }
                    }

                    // Customer ID on separate line
                    if let customerId = currentUser?.customerId, !customerId.isEmpty {
                        HStack(spacing: ResponsiveDesign.spacing(4)) {
                            Text("Customer ID:")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.tertiaryText)

                            Text(customerId)
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.tertiaryText)
                        }
                    }

                    // Account Number on separate line
                    HStack(spacing: ResponsiveDesign.spacing(4)) {
                        Text("Account Number:")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.tertiaryText)

                        Text("1234567890")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.tertiaryText)
                    }
                }

                Spacer()
            }

            // Last Login Info (very subtle)
            if let lastLogin = currentUser?.lastLoginDate {
                HStack {
                    Text("Last login: \(lastLogin.formatted(date: .abbreviated, time: .shortened))")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.quaternaryText)

                    Spacer()
                }
            }

            // Logout countdown timer
            HStack(spacing: ResponsiveDesign.spacing(8)) {
                Text("Logout:")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.tertiaryText)

                Text(formatTime(logoutTimeRemaining))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(logoutTimeRemaining <= 300 ? AppTheme.accentRed : AppTheme.tertiaryText) // Red when ≤ 5 minutes
                    .frame(width: 50, alignment: .leading) // Fixed width to prevent + symbol movement
                    .animation(.easeInOut(duration: 0.3), value: logoutTimeRemaining)

                // Add 15 minutes button (directly after timer)
                Button(action: addFifteenMinutes, label: {
                    Image(systemName: "plus.circle.fill")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.tertiaryText)
                })
                .disabled(logoutTimeRemaining <= 0)

                Spacer()
            }
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground.opacity(0.5))
        .cornerRadius(ResponsiveDesign.spacing(12))
        .onAppear {
            // Initialize current user state
            currentUser = appServices.userService.currentUser
            startLogoutTimer()
        }
        .onDisappear {
            stopLogoutTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDataDidUpdate)) { _ in
            // Update local state when user data (including role) changes
            currentUser = appServices.userService.currentUser
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserRoleChanged"))) { _ in
            // Update local state when role changes
            currentUser = appServices.userService.currentUser
        }
        .overlay(
            // Logout warning notification
            Group {
                if showLogoutWarning {
                    VStack {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppTheme.accentRed)
                            Text("Auto-logout in 2 minutes")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.fontColor)
                            Spacer()
                            Button("Dismiss") {
                                showLogoutWarning = false
                            }
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.accentLightBlue)
                        }
                        .padding(ResponsiveDesign.spacing(12))
                        .background(AppTheme.accentRed.opacity(0.1))
                        .cornerRadius(ResponsiveDesign.spacing(8))
                        .padding(.horizontal, ResponsiveDesign.spacing(16))

                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: showLogoutWarning)
                }
            }
        )
    }

    // MARK: - Timer Functions

    private func startLogoutTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if logoutTimeRemaining > 0 {
                logoutTimeRemaining -= 1

                // Show warning at 2 minutes (120 seconds)
                if logoutTimeRemaining == 120 && !showLogoutWarning {
                    showLogoutWarning = true
                }
            } else {
                // Auto logout when timer reaches 0
                performAutoLogout()
            }
        }
    }

    private func stopLogoutTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func addFifteenMinutes() {
        logoutTimeRemaining += 15 * 60 // Add 15 minutes
        // Hide warning if time is extended beyond 2 minutes
        if logoutTimeRemaining > 120 {
            showLogoutWarning = false
        }
    }

    private func performAutoLogout() {
        stopLogoutTimer()
        // Perform logout
        Task {
            await appServices.userService.signOut()
        }
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    DashboardWelcomeHeader()
}
