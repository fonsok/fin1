import SwiftUI

struct ModularProfileView: View {
    @Environment(\.appServices) private var appServices
    @StateObject private var viewModel: ModularProfileViewModel
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var showNotifications = false
    @State private var showLogoutAlert = false
    @State private var showHelpCenter = false
    @State private var showTermsOfService = false
    @State private var showPrivacyPolicy = false
    @State private var showImprint = false
    @State private var showPrivacySettings = false
    @State private var showSecuritySettings = false
    @State private var showAppearanceSettings = false
    @State private var showContactSupport = false

    init() {
        // Initialize ViewModel with services from environment
        // Note: Services will be injected when view appears via reconfigure
        let services = AppServices.live
        _viewModel = StateObject(wrappedValue: ModularProfileViewModel(
            notificationService: services.notificationService,
            userService: services.userService,
            documentService: services.documentService
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(24)) {
                        // Profile Header
                        ProfileHeaderView(user: self.appServices.userService.currentUser)

                        // Logout + Notifications grouped for consistent placement
                        profilePrimaryActionsSection

                        // Quick Actions
                        ProfileQuickActionsView(
                            onEditProfile: { self.showEditProfile = true },
                            onSettings: { self.showSettings = true },
                            onSecurity: { self.showSecuritySettings = true },
                            onHelpSupport: { self.showHelpCenter = true }
                        )

                        // Settings & Preferences
                        ProfileSettingsView(
                            onPrivacy: { self.showPrivacySettings = true },
                            onSecurity: { self.showSecuritySettings = true },
                            onAppearance: { self.showAppearanceSettings = true }
                        )

                        // Support & Legal
                        ProfileSupportView(
                            onHelpCenter: { self.showHelpCenter = true },
                            onContactSupport: { self.showContactSupport = true },
                            onTermsOfService: {
                                self.showTermsOfService = true
                            },
                            onPrivacyPolicy: { self.showPrivacyPolicy = true },
                            onImprint: { self.showImprint = true }
                        )

                        // Account Information
                        ProfileAccountInfoView(
                            user: self.appServices.userService.currentUser,
                            onEditProfile: { self.showEditProfile = true }
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    .scrollSection()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        self.showEditProfile = true
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
        .sheet(isPresented: self.$showEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: self.$showSettings) {
            SettingsView()
        }
        .sheet(isPresented: self.$showNotifications) {
            NotificationsView(services: self.appServices)
        }
        .sheet(isPresented: self.$showHelpCenter) {
            HelpCenterView()
        }
        .sheet(isPresented: self.$showTermsOfService) {
            TermsOfServiceView(
                configurationService: self.appServices.configurationService,
                termsContentService: self.appServices.termsContentService
            )
        }
        .sheet(isPresented: self.$showPrivacyPolicy) {
            PrivacyPolicyView(
                userService: self.appServices.userService,
                termsContentService: self.appServices.termsContentService
            )
        }
        .sheet(isPresented: self.$showImprint) {
            ImprintView(termsContentService: self.appServices.termsContentService)
        }
        .sheet(isPresented: self.$showPrivacySettings) {
            PrivacySettingsView()
        }
        .sheet(isPresented: self.$showSecuritySettings) {
            SecuritySettingsView()
        }
        .sheet(isPresented: self.$showContactSupport) {
            ContactSupportView()
        }
        .task {
            // Ensure ViewModel is using the same service instances from environment
            // Note: AppServices.live should be the same instance, but this ensures consistency
            self.viewModel.updateCounts()
        }
        .alert("Logout", isPresented: self.$showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                Task {
                    await self.appServices.userService.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
    }

    // MARK: - Helper Functions
    // Helper functions removed - using NotificationService properties directly

    // MARK: - Notifications Button
    private var notificationsButton: some View {
        Button(action: {
            self.showNotifications = true
        }) {
            HStack(spacing: ResponsiveDesign.spacing(16)) {
                // Icon with unread count badge
                ZStack {
                    Image(systemName: "bell.fill")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.accentOrange)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.accentOrange.opacity(0.1))
                        .clipShape(Circle())

                    // Unread count badge (includes notifications + documents)
                    if self.viewModel.combinedUnreadCount > 0 {
                        Text("\(self.viewModel.combinedUnreadCount)")
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.screenBackground)
                            .frame(width: 18, height: 18)
                            .background(AppTheme.accentRed)
                            .clipShape(Circle())
                            .offset(x: 12, y: -12)
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Notifications")
                            .font(ResponsiveDesign.headlineFont())
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.fontColor)

                        Spacer()

                        Text("\(self.viewModel.totalNotificationsCount)")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    }

                    Text("\(self.viewModel.combinedUnreadCount) unread")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.accentLightBlue)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
            }
            .padding(ResponsiveDesign.spacing(16))
            .background(AppTheme.systemTertiaryBackground)
            .cornerRadius(ResponsiveDesign.spacing(12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Subviews
private extension ModularProfileView {
    @ViewBuilder
    var profilePrimaryActionsSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            ProfileLogoutButton(onLogout: { self.showLogoutAlert = true })
            self.notificationsButton
        }
    }
}

#Preview {
    ModularProfileView()
}
