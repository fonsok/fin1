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
                        ProfileHeaderView(user: appServices.userService.currentUser)

                        // Logout + Notifications grouped for consistent placement
                        profilePrimaryActionsSection

                        // Quick Actions
                        ProfileQuickActionsView(
                            onEditProfile: { showEditProfile = true },
                            onSettings: { showSettings = true },
                            onSecurity: { showSecuritySettings = true },
                            onHelpSupport: { showHelpCenter = true }
                        )

                        // Settings & Preferences
                        ProfileSettingsView(
                            onPrivacy: { showPrivacySettings = true },
                            onSecurity: { showSecuritySettings = true },
                            onAppearance: { showAppearanceSettings = true }
                        )

                        // Support & Legal
                        ProfileSupportView(
                            onHelpCenter: { showHelpCenter = true },
                            onContactSupport: { showContactSupport = true },
                            onTermsOfService: {
                                showTermsOfService = true
                            },
                            onPrivacyPolicy: { showPrivacyPolicy = true },
                            onImprint: { showImprint = true }
                        )

                        // Account Information
                        ProfileAccountInfoView(
                            user: appServices.userService.currentUser,
                            onEditProfile: { showEditProfile = true }
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
                        showEditProfile = true
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView(services: appServices)
        }
        .sheet(isPresented: $showHelpCenter) {
            HelpCenterView()
        }
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView(
                configurationService: appServices.configurationService,
                termsContentService: appServices.termsContentService
            )
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView(
                userService: appServices.userService,
                termsContentService: appServices.termsContentService
            )
        }
        .sheet(isPresented: $showImprint) {
            ImprintView(termsContentService: appServices.termsContentService)
        }
        .sheet(isPresented: $showPrivacySettings) {
            PrivacySettingsView()
        }
        .sheet(isPresented: $showSecuritySettings) {
            SecuritySettingsView()
        }
        .sheet(isPresented: $showContactSupport) {
            ContactSupportView()
        }
        .task {
            // Ensure ViewModel is using the same service instances from environment
            // Note: AppServices.live should be the same instance, but this ensures consistency
            viewModel.updateCounts()
        }
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                Task {
                    await appServices.userService.signOut()
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
            showNotifications = true
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
                    if viewModel.combinedUnreadCount > 0 {
                        Text("\(viewModel.combinedUnreadCount)")
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

                        Text("\(viewModel.totalNotificationsCount)")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    }

                    Text("\(viewModel.combinedUnreadCount) unread")
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
            ProfileLogoutButton(onLogout: { showLogoutAlert = true })
            notificationsButton
        }
    }
}

#Preview {
    ModularProfileView()
}
