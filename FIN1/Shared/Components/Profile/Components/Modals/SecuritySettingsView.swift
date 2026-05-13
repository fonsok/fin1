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
                    VStack(spacing: ResponsiveDesign.spacing(24)) {
                        self.headerSection
                        self.biometricSection
                        self.twoFactorSection
                        self.passwordSection
                        self.sessionSecuritySection
                        self.securityActivitySection
                        self.quickActionsSection
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(16))
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

            Text("Protect your account with advanced security features")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.top, ResponsiveDesign.spacing(16))
    }

    // MARK: - Biometric Section

    private var biometricSection: some View {
        self.securitySection(title: "Biometric Authentication", icon: self.viewModel.biometricType.iconName, color: AppTheme.accentGreen) {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                if self.viewModel.isBiometricAvailable {
                    self.biometricToggle
                    SecurityToggleRow(
                        title: "Require Password on Launch",
                        subtitle: "Always require password when opening the app",
                        isEnabled: self.$viewModel.requirePasswordOnLaunch
                    )
                } else {
                    self.biometricUnavailableMessage
                }
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
        self.securitySection(title: "Two-Factor Authentication", icon: "shield.checkered", color: AppTheme.accentLightBlue) {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                SecurityToggleRow(
                    title: "Enable 2FA",
                    subtitle: "Add an extra layer of security to your account",
                    isEnabled: self.$viewModel.twoFactorEnabled
                )
                if self.viewModel.twoFactorEnabled {
                    self.twoFactorMethodPicker
                    self.configure2FAButton
                }
            }
        }
    }

    private var twoFactorMethodPicker: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Verification Method")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
            ForEach(TwoFactorMethod.allCases, id: \.self) { method in
                TwoFactorMethodRow(method: method, isSelected: self.viewModel.twoFactorMethod == method) {
                    self.viewModel.twoFactorMethod = method
                }
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
            .padding(ResponsiveDesign.spacing(12))
            .background(AppTheme.systemTertiaryBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
    }

    // MARK: - Password Section

    private var passwordSection: some View {
        self.securitySection(title: "Password", icon: "key.fill", color: AppTheme.accentOrange) {
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                self.changePasswordButton
                self.autoLockPicker
            }
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
            .padding(ResponsiveDesign.spacing(12))
            .background(AppTheme.systemTertiaryBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
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
        self.securitySection(title: "Session Security", icon: "desktopcomputer", color: AppTheme.accentRed) {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                SecurityToggleRow(
                    title: "Login Alerts",
                    subtitle: "Get notified when your account is accessed",
                    isEnabled: self.$viewModel.loginAlertsEnabled
                )
                SecurityToggleRow(
                    title: "Remember This Device",
                    subtitle: "Skip 2FA on trusted devices",
                    isEnabled: self.$viewModel.rememberDevice
                )
                self.signOutAllButton
            }
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
            .padding(ResponsiveDesign.spacing(12))
            .background(AppTheme.systemTertiaryBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
    }

    // MARK: - Security Activity Section

    private var securityActivitySection: some View {
        self.securitySection(title: "Recent Security Activity", icon: "clock.fill", color: AppTheme.accentLightBlue) {
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                ForEach(self.viewModel.recentSecurityEvents.prefix(3)) { SecurityEventRow(event: $0) }
                Button(action: { self.viewModel.showSecurityActivityLog = true }) {
                    Text("View All Activity")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        Button(action: { self.viewModel.resetToDefaults() }) {
            HStack {
                Image(systemName: "arrow.clockwise").font(ResponsiveDesign.bodyFont())
                Text("Reset to Defaults").font(ResponsiveDesign.bodyFont()).fontWeight(.medium)
            }
            .foregroundColor(AppTheme.accentLightBlue)
            .padding()
            .frame(maxWidth: .infinity)
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
    }

    // MARK: - Helper Methods

    private func securitySection<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            HStack {
                Image(systemName: icon).font(ResponsiveDesign.headlineFont()).foregroundColor(color).frame(width: 24)
                Text(title).font(ResponsiveDesign.headlineFont()).foregroundColor(AppTheme.fontColor)
                Spacer()
            }
            content()
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Preview

#Preview {
    SecuritySettingsView()
        .environment(\.appServices, AppServices.live)
}
