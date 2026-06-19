import SwiftUI

// MARK: - Security Settings View
/// User interface for managing security settings including biometrics, 2FA, and password
struct SecuritySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var appServices
    @StateObject private var viewModel: SecuritySettingsViewModel

    init() {
        let services = AppServices.live
        _viewModel = StateObject(wrappedValue: SecuritySettingsViewModel(
            userService: services.userService
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    StripedStepList {
                        self.headerSection
                            .stripedListSection(stripeIndex: 0)

                        self.biometricSection
                            .stripedListSection(stripeIndex: 1)

                        self.twoFactorSection
                            .stripedListSection(stripeIndex: 2)

                        self.passwordSection
                            .stripedListSection(stripeIndex: 3)

                        self.sessionSecuritySection
                            .stripedListSection(stripeIndex: 4)

                        self.securityActivitySection
                            .stripedListSection(stripeIndex: 5)

                        self.quickActionsSection
                            .stripedListSection(stripeIndex: 6)
                    }
                    .padding(.bottom, ResponsiveDesign.spacing(16))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { self.toolbarContent }
            .sheet(isPresented: self.$viewModel.showPasswordChange) {
                PasswordChangeSheet(viewModel: self.viewModel)
            }
            .sheet(isPresented: self.$viewModel.showTwoFactorSetup) {
                TwoFactorSetupSheet(viewModel: self.viewModel)
            }
            .sheet(isPresented: self.$viewModel.showSecurityActivityLog) {
                SecurityActivityLogSheet(events: self.viewModel.recentSecurityEvents)
            }
            .alert("Terminate Sessions", isPresented: self.$viewModel.showActiveSessionsAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Terminate All", role: .destructive) {
                    self.viewModel.terminateAllSessions()
                }
            } message: {
                Text("This will sign out all other devices. You will remain signed in on this device.")
            }
            .alert("Password Changed", isPresented: self.$viewModel.showPasswordChangeSuccess) {
                Button("OK") {}
            } message: {
                Text("Your password has been updated successfully.")
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") { self.dismiss() }
                .foregroundColor(AppTheme.fontColor)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") {
                self.viewModel.saveSettings()
                self.dismiss()
            }
            .foregroundColor(AppTheme.accentLightBlue)
            .fontWeight(.semibold)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: "lock.shield.fill")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                .foregroundColor(AppTheme.accentRed)

            Text("Security Settings")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
                .multilineTextAlignment(.center)

            Text("Protect your account with advanced security features")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Biometric Section

    private var biometricSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            ProfileIconSectionTitle(
                title: "Biometric Authentication",
                icon: self.viewModel.biometricType.iconName,
                color: AppTheme.accentGreen
            )

            if self.viewModel.isBiometricAvailable {
                ProfileSectionDivider()
                self.biometricToggle
                    .padding(.vertical, ResponsiveDesign.spacing(12))
                ProfileSectionDivider()
                SecurityToggleRow(
                    title: "Require Password on Launch",
                    subtitle: "Always require password when opening the app",
                    isEnabled: self.$viewModel.requirePasswordOnLaunch
                )
                .padding(.vertical, ResponsiveDesign.spacing(12))
            } else {
                ProfileSectionDivider()
                self.biometricUnavailableMessage
                    .padding(.vertical, ResponsiveDesign.spacing(12))
            }
        }
    }

    private var biometricToggle: some View {
        HStack {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text(self.viewModel.biometricType.rawValue)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)
                Text("Use \(self.viewModel.biometricType.rawValue) to unlock the app quickly")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { self.viewModel.biometricAuthEnabled },
                set: { $0 ? self.viewModel.enableBiometricAuth() : self.viewModel.disableBiometricAuth() }
            ))
            .toggleStyle(SwitchToggleStyle(tint: AppTheme.accentGreen))
        }
    }

    private var biometricUnavailableMessage: some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(AppTheme.accentOrange)
            Text("Biometric authentication is not available on this device")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
    }

    // MARK: - Two-Factor Section

    private var twoFactorSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            ProfileIconSectionTitle(title: "Two-Factor Authentication", icon: "shield.checkered", color: AppTheme.accentLightBlue)
            ProfileSectionDivider()
            SecurityToggleRow(
                title: "Enable 2FA",
                subtitle: "Add an extra layer of security to your account",
                isEnabled: self.$viewModel.twoFactorEnabled
            )
            .padding(.vertical, ResponsiveDesign.spacing(12))

            if self.viewModel.twoFactorEnabled {
                ProfileSectionDivider()
                self.twoFactorMethodPicker
                ProfileSectionDivider()
                self.configure2FAButton
            }
        }
    }

    private var twoFactorMethodPicker: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(0)) {
            Text("Verification Method")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .padding(.vertical, ResponsiveDesign.spacing(8))

            ForEach(Array(TwoFactorMethod.allCases.enumerated()), id: \.element) { index, method in
                if index > 0 {
                    ProfileSectionDivider()
                }
                TwoFactorMethodRow(method: method, isSelected: self.viewModel.twoFactorMethod == method) {
                    self.viewModel.twoFactorMethod = method
                }
                .padding(.vertical, ResponsiveDesign.spacing(8))
            }
        }
    }

    private var configure2FAButton: some View {
        Button(action: { self.viewModel.showTwoFactorSetup = true }) {
            HStack {
                Image(systemName: "gear").font(ResponsiveDesign.bodyFont())
                Text("Configure 2FA").font(ResponsiveDesign.bodyFont()).fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right").font(ResponsiveDesign.captionFont())
            }
            .foregroundColor(AppTheme.accentLightBlue)
            .padding(.vertical, ResponsiveDesign.spacing(12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Password Section

    private var passwordSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            ProfileIconSectionTitle(title: "Password", icon: "key.fill", color: AppTheme.accentOrange)
            ProfileSectionDivider()
            self.changePasswordButton
            ProfileSectionDivider()
            self.autoLockPicker
                .padding(.vertical, ResponsiveDesign.spacing(12))
        }
    }

    private var changePasswordButton: some View {
        Button(action: { self.viewModel.showPasswordChange = true }) {
            HStack {
                Image(systemName: "key.fill").font(ResponsiveDesign.bodyFont())
                Text("Change Password").font(ResponsiveDesign.bodyFont()).fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right").font(ResponsiveDesign.captionFont())
            }
            .foregroundColor(AppTheme.fontColor)
            .padding(.vertical, ResponsiveDesign.spacing(12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var autoLockPicker: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Auto-Lock")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
            Picker("Auto-Lock Timeout", selection: self.$viewModel.autoLockTimeout) {
                ForEach(AutoLockTimeout.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.accentLightBlue)
        }
    }

    // MARK: - Session Security Section

    private var sessionSecuritySection: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            ProfileIconSectionTitle(title: "Session Security", icon: "desktopcomputer", color: AppTheme.accentRed)
            ProfileSectionDivider()
            SecurityToggleRow(
                title: "Login Alerts",
                subtitle: "Get notified when your account is accessed",
                isEnabled: self.$viewModel.loginAlertsEnabled
            )
            .padding(.vertical, ResponsiveDesign.spacing(12))
            ProfileSectionDivider()
            SecurityToggleRow(
                title: "Remember This Device",
                subtitle: "Skip 2FA on trusted devices",
                isEnabled: self.$viewModel.rememberDevice
            )
            .padding(.vertical, ResponsiveDesign.spacing(12))
            ProfileSectionDivider()
            self.signOutAllButton
        }
    }

    private var signOutAllButton: some View {
        Button(action: { self.viewModel.showActiveSessionsAlert = true }) {
            HStack {
                Image(systemName: "xmark.circle.fill").font(ResponsiveDesign.bodyFont())
                Text("Sign Out All Other Devices").font(ResponsiveDesign.bodyFont()).fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right").font(ResponsiveDesign.captionFont())
            }
            .foregroundColor(AppTheme.accentRed)
            .padding(.vertical, ResponsiveDesign.spacing(12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Security Activity Section

    private var securityActivitySection: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            ProfileIconSectionTitle(title: "Recent Security Activity", icon: "clock.fill", color: AppTheme.accentLightBlue)

            if self.viewModel.recentSecurityEvents.isEmpty {
                ProfileSectionDivider()
                Text("No recent activity")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, ResponsiveDesign.spacing(12))
            } else {
                ForEach(Array(self.viewModel.recentSecurityEvents.prefix(3).enumerated()), id: \.element.id) { index, event in
                    ProfileSectionDivider()
                    SecurityEventRow(event: event, flatStyle: true)
                        .padding(.vertical, ResponsiveDesign.spacing(8))
                }
            }

            ProfileSectionDivider()
            Button(action: { self.viewModel.showSecurityActivityLog = true }) {
                Text("View All Activity")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.accentLightBlue)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, ResponsiveDesign.spacing(12))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        Button(action: { self.viewModel.resetToDefaults() }) {
            HStack {
                Image(systemName: "arrow.clockwise").font(ResponsiveDesign.bodyFont())
                Text("Reset to Defaults").font(ResponsiveDesign.bodyFont()).fontWeight(.medium)
                Spacer()
            }
            .foregroundColor(AppTheme.accentLightBlue)
            .padding(.vertical, ResponsiveDesign.spacing(4))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    SecuritySettingsView()
        .environment(\.appServices, AppServices.live)
}
