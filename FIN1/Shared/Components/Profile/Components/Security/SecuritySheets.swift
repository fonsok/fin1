import SwiftUI

// MARK: - Password Change Sheet

struct PasswordChangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SecuritySettingsViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: ResponsiveDesign.spacing(24)) {
                    self.passwordFields
                    self.errorSection
                    self.helpText
                    self.changeButton
                    Spacer()
                }
                .padding(ResponsiveDesign.spacing(24))
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { self.dismiss() }
                        .foregroundColor(AppTheme.fontColor)
                }
            }
        }
    }

    private var passwordFields: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            SecureField("Current Password", text: self.$viewModel.currentPassword)
                .textFieldStyle(SettingsSecureFieldStyle())

            SecureField("New Password", text: self.$viewModel.newPassword)
                .textFieldStyle(SettingsSecureFieldStyle())

            SecureField("Confirm New Password", text: self.$viewModel.confirmPassword)
                .textFieldStyle(SettingsSecureFieldStyle())
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = viewModel.passwordChangeError {
            Text(error)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.accentRed)
        }
    }

    private var helpText: some View {
        Text("Password must be at least 8 characters long")
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(AppTheme.fontColor.opacity(0.6))
    }

    private var changeButton: some View {
        Button(action: { self.viewModel.changePassword() }) {
            HStack {
                if self.viewModel.isChangingPassword {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Change Password")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.accentLightBlue)
            .foregroundColor(.white)
            .cornerRadius(ResponsiveDesign.spacing(12))
        }
        .disabled(self.viewModel.isChangingPassword)
    }
}

// MARK: - Two-Factor Setup Sheet

struct TwoFactorSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SecuritySettingsViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: ResponsiveDesign.spacing(24)) {
                    self.headerIcon
                    self.titleSection
                    self.descriptionText
                    self.methodInfoCard
                    Spacer()
                    self.doneButton
                }
                .padding(ResponsiveDesign.spacing(24))
            }
            .navigationTitle("Configure 2FA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { self.dismiss() }
                        .foregroundColor(AppTheme.fontColor)
                }
            }
        }
    }

    private var headerIcon: some View {
        Image(systemName: "shield.checkered")
            .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 3))
            .foregroundColor(AppTheme.accentLightBlue)
    }

    private var titleSection: some View {
        Text("Two-Factor Authentication")
            .font(ResponsiveDesign.headlineFont())
            .fontWeight(.bold)
            .foregroundColor(AppTheme.fontColor)
    }

    private var descriptionText: some View {
        Text(
            "Two-factor authentication adds an extra layer of security to your account by requiring a verification code in addition to your password."
        )
        .font(ResponsiveDesign.bodyFont())
        .foregroundColor(AppTheme.fontColor.opacity(0.7))
        .multilineTextAlignment(.center)
    }

    private var methodInfoCard: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            Text("Selected Method: \(self.viewModel.twoFactorMethod.rawValue)")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)

            Text(self.setupInstructions)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var doneButton: some View {
        Button(action: { self.dismiss() }) {
            Text("Done")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.accentLightBlue)
                .foregroundColor(.white)
                .cornerRadius(ResponsiveDesign.spacing(12))
        }
    }

    private var setupInstructions: String {
        switch self.viewModel.twoFactorMethod {
        case .sms:
            return "We will send a verification code to your registered phone number each time you sign in."
        case .email:
            return "We will send a verification code to your registered email address each time you sign in."
        case .authenticatorApp:
            return "Use an authenticator app like Google Authenticator or Authy to generate verification codes."
        }
    }
}

// MARK: - Security Activity Log Sheet

struct SecurityActivityLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    let events: [SecurityEvent]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(12)) {
                        ForEach(self.events) { event in
                            SecurityEventRow(event: event)
                        }
                    }
                    .padding(ResponsiveDesign.spacing(16))
                }
            }
            .navigationTitle("Security Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { self.dismiss() }
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }
}





