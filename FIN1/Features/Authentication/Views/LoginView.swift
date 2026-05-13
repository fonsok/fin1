import LocalAuthentication
import SwiftUI

// MARK: - Login View Wrapper
/// Wrapper to properly inject services from environment into ViewModel
struct LoginViewWrapper: View {
    @Environment(\.appServices) private var services

    var body: some View {
        LoginView(userService: self.services.userService)
    }
}

// MARK: - Login View
struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AuthenticationViewModel
    @Environment(\.themeManager) private var themeManager

    init(userService: any UserServiceProtocol) {
        self._viewModel = StateObject(wrappedValue: AuthenticationViewModel(userService: userService))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(32)) {
                        // Header
                        VStack(spacing: ResponsiveDesign.spacing(16)) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(ResponsiveDesign.scaledSystemFont(size: 60))
                                .foregroundColor(AppTheme.accentLightBlue)

                            Text("Welcome Back")
                                .font(ResponsiveDesign.titleFont())
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.fontColor)

                            Text("Sign in to your \(AppBrand.appName) account")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.secondaryText)
                        }
                        .padding(.top, 40)

                        // Login Form
                        VStack(spacing: ResponsiveDesign.spacing(20)) {
                            LabeledInputField(
                                label: "Email",
                                placeholder: "Enter your email",
                                icon: "envelope.fill",
                                text: self.$viewModel.email,
                                isEmail: true
                            )

                            LabeledSecureField(
                                label: "Password",
                                placeholder: "Enter your password",
                                icon: "lock.fill",
                                text: self.$viewModel.password
                            )

                            // Forgot Password
                            HStack {
                                Spacer()
                                Button("Forgot Password?") {
                                    self.viewModel.showForgotPassword = true
                                }
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.accentLightBlue)
                            }
                        }
                        .authPadding()

                        // Login Button
                        Button(action: self.viewModel.performLogin, label: {
                            HStack {
                                if self.viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Sign In")
                                        .font(ResponsiveDesign.headlineFont())
                                }
                            }
                            .foregroundColor(AppTheme.screenBackground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppTheme.accentLightBlue)
                            .cornerRadius(ResponsiveDesign.spacing(12))
                        })
                        .disabled(self.viewModel.isLoading)
                        .authPadding()

                        // Biometric Login
                        Button(action: self.viewModel.performBiometricLogin, label: {
                            HStack(spacing: ResponsiveDesign.spacing(12)) {
                                Image(systemName: "faceid")
                                    .font(ResponsiveDesign.headlineFont())
                                Text("Sign in with Face ID")
                                    .font(ResponsiveDesign.headlineFont())
                            }
                            .foregroundColor(AppTheme.accentLightBlue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                                    .stroke(AppTheme.accentLightBlue, lineWidth: 2)
                            )
                        })
                        .authPadding()

                        Spacer()
                    }
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
        .dismissKeyboardOnTap()
        .alert("Login Error", isPresented: self.$viewModel.showError) {
            Button("OK") { self.viewModel.clearError() }
        } message: {
            Text(self.viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: self.$viewModel.showForgotPassword) {
            ForgotPasswordView()
        }
        // Use onAppear to check authentication state immediately
        .onAppear {
            // Reset state when view appears
            self.viewModel.loginSuccessful = false
        }
        // Use onReceive for more reliable state observation
        .onReceive(self.viewModel.$isAuthenticated) { isAuthenticated in
            if isAuthenticated && self.viewModel.loginSuccessful {
                // Add a very small delay to allow state to update completely
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.viewModel.isLoading = false
                    self.dismiss()
                }
            }
        }
    }
}

// MARK: - Legacy Components (for backward compatibility)
struct CustomTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: self.icon)
                .foregroundColor(AppTheme.inputFieldPlaceholder)
                .frame(width: 20)

            TextField(self.placeholder, text: self.$text)
                .font(ResponsiveDesign.headlineFont()) // Increased font size by another ~50%
                .foregroundColor(AppTheme.inputFieldText)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
        }
        .padding()
        .background(AppTheme.inputFieldBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

struct CustomSecureField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: self.icon)
                .foregroundColor(AppTheme.inputFieldPlaceholder)
                .frame(width: 20)

            SecureField(self.placeholder, text: self.$text)
                .font(ResponsiveDesign.headlineFont()) // Increased font size by another ~50%
                .foregroundColor(AppTheme.inputFieldText)
                .textContentType(.password)
        }
        .padding()
        .background(AppTheme.inputFieldBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

#Preview {
    LoginViewWrapper()
}
