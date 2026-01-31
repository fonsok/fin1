import Foundation
import LocalAuthentication

// MARK: - Authentication Coordinator
/// Handles the core authentication logic and biometric authentication
struct AuthenticationCoordinator {

    // MARK: - Biometric Authentication

    static func performBiometricLogin(
        userService: any UserServiceProtocol,
        onSuccess: @escaping () -> Void,
        onError: @escaping (AppError) -> Void
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
                Task {
                    do {
                        // Must satisfy Parse Server password policy (uppercase/lowercase/digit/special)
                        try await userService.signIn(email: "biometric@example.com", password: "Password123!")
                        await MainActor.run {
                            onSuccess()
                        }
                    } catch {
                        await MainActor.run {
                            onError(AppError.authenticationError(.invalidCredentials))
                        }
                    }
                }
            } else {
                onError(AppError.authenticationError(.invalidCredentials))
            }
        }
    }

    // MARK: - Sign In Logic

    static func performSignIn(
        email: String,
        password: String,
        userService: any UserServiceProtocol,
        onSuccess: @escaping () -> Void,
        onError: @escaping (AppError) -> Void
    ) {
        // Mock authentication logic
        if email.lowercased() == "test@example.com" && password == "password" {
            Task {
                do {
                    try await userService.signIn(email: email, password: password)
                    await MainActor.run {
                        onSuccess()
                    }
                } catch {
                    await MainActor.run {
                        onError(AppError.authenticationError(.invalidCredentials))
                    }
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
        onSuccess: @escaping () -> Void,
        onError: @escaping (AppError) -> Void
    ) {
        do {
            let newUser = try userData.createUser()
            Task {
                do {
                    try await userService.signUp(userData: newUser)
                    await MainActor.run {
                        onSuccess()
                    }
                } catch {
                    await MainActor.run {
                        onError(AppError.authenticationError(.emailAlreadyExists))
                    }
                }
            }
        } catch {
            onError(AppError.authenticationError(.weakPassword))
        }
    }
}
