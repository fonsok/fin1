import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: ResponsiveDesign.spacing(32)) {
                    // Header
                    VStack(spacing: ResponsiveDesign.spacing(16)) {
                        Image(systemName: "lock.rotation")
                            .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 3))
                            .foregroundColor(AppTheme.accentLightBlue)

                        Text("Reset Password")
                            .font(ResponsiveDesign.titleFont())
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.fontColor)

                        Text("Enter your email address and we'll send you a link to reset your password")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)

                    // Email Form
                    VStack(spacing: ResponsiveDesign.spacing(20)) {
                        LabeledInputField(
                            label: "Email Address",
                            placeholder: "Enter your email address",
                            icon: "envelope.fill",
                            text: self.$email,
                            isEmail: true
                        )
                        .authPadding()

                        // Reset Button
                        Button(action: self.resetPassword, label: {
                            HStack {
                                if self.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Send Reset Link")
                                        .font(ResponsiveDesign.headlineFont())
                                }
                            }
                            .foregroundColor(AppTheme.screenBackground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppTheme.accentLightBlue)
                            .cornerRadius(ResponsiveDesign.spacing(12))
                        })
                        .disabled(self.isLoading || self.email.isEmpty)
                        .authPadding()
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        self.dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
        .alert(self.isSuccess ? "Success" : "Error", isPresented: self.$showAlert) {
            Button("OK") {
                if self.isSuccess {
                    self.dismiss()
                }
            }
        } message: {
            Text(self.alertMessage)
        }
    }

    private func resetPassword() {
        guard !self.email.isEmpty else {
            self.alertMessage = "Please enter your email address"
            self.showAlert = true
            return
        }

        self.isLoading = true

        // Simulate password reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isLoading = false
            self.isSuccess = true
            self.alertMessage = "Password reset link has been sent to your email"
            self.showAlert = true
        }
    }
}

#Preview {
    ForgotPasswordView()
}
