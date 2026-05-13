import SwiftUI

struct DirectLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var appServices
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.themeManager) private var themeManager

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
                                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 3))
                                .foregroundColor(AppTheme.accentLightBlue)

                            Text("Simple Login")
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
                            TextField("Email", text: self.$email)
                                .font(ResponsiveDesign.headlineFont())
                                .padding()
                                .background(AppTheme.inputFieldBackground)
                                .cornerRadius(ResponsiveDesign.spacing(12))
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .foregroundColor(AppTheme.inputFieldText)

                            SecureField("Password", text: self.$password)
                                .font(ResponsiveDesign.headlineFont())
                                .padding()
                                .background(AppTheme.inputFieldBackground)
                                .cornerRadius(ResponsiveDesign.spacing(12))
                                .foregroundColor(AppTheme.inputFieldText)
                        }
                        .padding(.horizontal)

                        // Login Button
                        Button(action: self.performLogin, label: {
                            HStack {
                                if self.isLoading {
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
                        .disabled(self.isLoading)
                        .padding(.horizontal)

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
        .alert(isPresented: self.$showAlert) {
            Alert(
                title: Text("Login Error"),
                message: Text(self.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func performLogin() {
        guard !self.email.isEmpty && !self.password.isEmpty else {
            self.alertMessage = "Please fill in all fields"
            self.showAlert = true
            return
        }

        self.isLoading = true

        // Perform login asynchronously
        Task {
            do {
                try await self.appServices.userService.signIn(email: self.email, password: self.password)
                await MainActor.run {
                    self.isLoading = false
                    self.dismiss()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.alertMessage = "Login failed. Please try again."
                    self.showAlert = true
                }
            }
        }
    }
}

#Preview {
    DirectLoginView()
        .environmentObject(UserService.shared) // Preview fallback allowed
}
