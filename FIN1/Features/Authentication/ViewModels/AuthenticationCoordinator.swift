import Foundation
import LocalAuthentication

// MARK: - Authentication Coordinator
/// Handles the core authentication logic and biometric authentication
@MainActor
struct AuthenticationCoordinator {

    // MARK: - Biometric Authentication

    static func performBiometricLogin(
        userService: any UserServiceProtocol,
        onSuccess: @escaping @MainActor () -> Void,
        onError: @escaping @MainActor (AppError) -> Void
    ) {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            onError(AppError.authenticationError(.invalidCredentials))
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                             localizedReason: "Sign in to \(AppBrand.appName)") { success, _ in
            if success {
                Task { @MainActor in
                    do {
                        // Must satisfy Parse Server password policy (uppercase/lowercase/digit/special)
                        try await userService.signIn(email: "biometric@example.com", password: TestConstants.password)
                        onSuccess()
                    } catch {
                        onError(AppError.authenticationError(.invalidCredentials))
                    }
                }
            } else {
                Task { @MainActor in
                    onError(AppError.authenticationError(.invalidCredentials))
                }
            }
        }
    }

    // MARK: - Sign In Logic

    static func performSignIn(
        email: String,
        password: String,
        userService: any UserServiceProtocol,
        onSuccess: @escaping @MainActor () -> Void,
        onError: @escaping @MainActor (AppError) -> Void
    ) {
        // Mock authentication logic
        if email.lowercased() == "test@example.com" && password == "password" {
            Task { @MainActor in
                do {
                    try await userService.signIn(email: email, password: password)
                    onSuccess()
                } catch {
                    onError(AppError.authenticationError(.invalidCredentials))
                }
            }
        } else {
            onError(AppError.authenticationError(.invalidCredentials))
        }
    }

    // MARK: - Sign Up Logic

    static func performSignUp(
        userData: SignUpData,
        userService: any UserServiceProtocol,
        onSuccess: @escaping @MainActor () -> Void,
        onError: @escaping @MainActor (AppError) -> Void
    ) {
        do {
            let newUser = try userData.createUser()
            Task { @MainActor in
                do {
                    try await userService.signUp(userData: newUser)
                    onSuccess()
                } catch {
                    onError(AppError.authenticationError(.emailAlreadyExists))
                }
            }
        } catch {
            onError(AppError.authenticationError(.weakPassword))
        }
    }
}
