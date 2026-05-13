import Foundation
import LocalAuthentication
import SwiftUI

@MainActor
final class AuthenticationViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var showError = false

    // Login form state
    @Published var email = ""
    @Published var password = ""
    @Published var showForgotPassword = false
    @Published var loginSuccessful = false

    private let userService: any UserServiceProtocol

    init(userService: any UserServiceProtocol) {
        self.userService = userService
        self.setupObservers()
    }

    deinit {
        removeObservers()
        print("🧹 AuthenticationViewModel deallocated")
    }

    // MARK: - Authentication State

    var isLoggedIn: Bool {
        self.userService.isAuthenticated
    }

    var userDisplayName: String {
        self.currentUser?.displayName ?? "Guest"
    }

    var userRole: UserRole? {
        self.currentUser?.role
    }

    var isInvestor: Bool {
        self.currentUser?.role == .investor
    }

    var isTrader: Bool {
        self.currentUser?.role == .trader
    }

    // MARK: - Setup and Observers

    private func setupObservers() {
        // Observe authentication state changes
        NotificationCenter.default.addObserver(
            forName: .userDidSignIn,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleUserSignIn()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .userDidSignOut,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleUserSignOut()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .userDataDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleUserDataUpdate()
            }
        }
    }

    nonisolated private func removeObservers() {
        // Note: NotificationCenter observers are automatically removed in deinit
        // This method is kept for potential future use
    }

    // MARK: - Authentication Methods

    func signIn(email: String, password: String) {
        self.isLoading = true
        self.errorMessage = nil

        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.performSignIn(email: email, password: password)
        }
    }

    func performLogin() {
        let validation = AuthenticationValidation.validateLoginForm(email: self.email, password: self.password)

        guard validation.isValid else {
            self.showError(AppError.validationError(validation.errorMessage ?? "Invalid input"))
            return
        }

        // Set loading state
        self.isLoading = true

        // Use regular email format to avoid triggering test user path
        let loginEmail = self.email.contains("@") ? self.email : self.email + "@example.com"

        Task { [weak self] in
            do {
                try await self?.userService.signIn(email: loginEmail, password: self?.password ?? "")
                await MainActor.run { [weak self] in
                    self?.loginSuccessful = true
                    self?.isLoading = false
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.showError(AppError.authenticationError(.invalidCredentials))
                    self?.isLoading = false
                }
            }
        }
    }

    func performBiometricLogin() {
        AuthenticationCoordinator.performBiometricLogin(
            userService: self.userService,
            onSuccess: { [weak self] in
                self?.loginSuccessful = true
                self?.isLoading = false
            },
            onError: { [weak self] error in
                self?.showError(error)
                self?.isLoading = false
            }
        )
    }

    func performSignUp(userData: SignUpData) {
        let validation = AuthenticationValidation.validateSignUpForm(userData: userData)

        guard validation.isValid else {
            self.showError(AppError.validationError(validation.errorMessage ?? "Invalid input"))
            return
        }

        self.isLoading = true

        AuthenticationCoordinator.performSignUp(
            userData: userData,
            userService: self.userService,
            onSuccess: { [weak self] in
                self?.currentUser = self?.userService.currentUser
                self?.isAuthenticated = self?.userService.isAuthenticated ?? false
                self?.isLoading = false
            },
            onError: { [weak self] error in
                self?.showError(error)
                self?.isLoading = false
            }
        )
    }

    func signOut() {
        Task { [weak self] in
            await self?.userService.signOut()
            await MainActor.run { [weak self] in
                self?.handleUserSignOut()
            }
        }
    }

    // MARK: - Private Implementation Methods

    private func performSignIn(email: String, password: String) {
        AuthenticationCoordinator.performSignIn(
            email: email,
            password: password,
            userService: self.userService,
            onSuccess: { [weak self] in
                self?.currentUser = self?.userService.currentUser
                self?.isAuthenticated = self?.userService.isAuthenticated ?? false
                self?.isLoading = false
            },
            onError: { [weak self] error in
                self?.showError(error)
                self?.isLoading = false
            }
        )
    }

    // MARK: - Notification Handlers

    private func handleUserSignIn() {
        self.currentUser = self.userService.currentUser
        self.isAuthenticated = self.userService.isAuthenticated
    }

    private func handleUserSignOut() {
        self.currentUser = nil
        self.isAuthenticated = false
    }

    private func handleUserDataUpdate() {
        self.currentUser = self.userService.currentUser
    }

    // MARK: - Error Handling

    func clearError() {
        self.errorMessage = nil
        self.showError = false
    }

    func showError(_ message: String) {
        self.errorMessage = message
        self.showError = true
    }

    func showError(_ error: AppError) {
        self.errorMessage = error.errorDescription ?? "An error occurred"
        self.showError = true

        // Track error with user context
        let context = ErrorContext(
            screen: "Authentication",
            action: "user_action",
            userId: currentUser?.id,
            userRole: self.currentUser?.role.displayName,
            additionalData: [
                "is_authenticated": self.isAuthenticated,
                "email_provided": !self.email.isEmpty,
                "password_provided": !self.password.isEmpty
            ]
        )
        TelemetryService.shared.trackAppError(error, context: context)
    }

    // MARK: - Validation (Delegated to AuthenticationValidation)

    func validateEmail(_ email: String) -> Bool {
        return AuthenticationValidation.validateEmail(email)
    }

    func validatePassword(_ password: String) -> Bool {
        return AuthenticationValidation.validatePassword(password)
    }

    func getPasswordStrength(_ password: String) -> PasswordStrength {
        return AuthenticationValidation.getPasswordStrength(password)
    }
}
