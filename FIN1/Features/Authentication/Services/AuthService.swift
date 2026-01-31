import Foundation
import LocalAuthentication
import OSLog

// MARK: - Auth Service Protocol
/// High-level authentication service that integrates auth providers with the app
protocol AuthServiceProtocol: AnyObject {
    /// Current authentication state
    var isAuthenticated: Bool { get }

    /// Current user ID (if authenticated)
    var currentUserId: String? { get }

    /// Sign in with email and password
    func signIn(email: String, password: String) async throws -> AuthResult

    /// Sign in with Apple
    func signInWithApple(identityToken: Data, authorizationCode: Data, fullName: PersonNameComponents?) async throws -> AuthResult

    /// Sign in with biometrics (re-authentication)
    func signInWithBiometrics() async throws -> AuthResult

    /// Sign in with SSO provider
    func signInWithSSO(provider: SSOProvider, code: String, state: String?) async throws -> AuthResult

    /// Sign out and clear all tokens
    func signOut() async throws

    /// Refresh the current session
    func refreshSession() async throws

    /// Check if biometric authentication is available
    var isBiometricAvailable: Bool { get }
}

// MARK: - Auth Service Implementation
/// Default implementation of AuthServiceProtocol
final class AuthService: AuthServiceProtocol, ObservableObject, ServiceLifecycle {

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.fin1.app", category: "AuthService")

    // MARK: - Published Properties

    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var currentUserId: String?

    // MARK: - Dependencies

    private let authProvider: AuthProviderProtocol
    private let tokenStorage: TokenStorageProtocol

    // MARK: - Private State

    private var currentAuthResult: AuthResult?
    private var isStarted: Bool = false

    // MARK: - Initialization

    init(
        authProvider: AuthProviderProtocol,
        tokenStorage: TokenStorageProtocol
    ) {
        self.authProvider = authProvider
        self.tokenStorage = tokenStorage
        // Note: Don't use Task in init() - use ServiceLifecycle.start() instead
    }

    // MARK: - ServiceLifecycle Implementation

    func start() {
        guard !isStarted else { return }
        isStarted = true
        logger.info("🔐 AuthService started")

        // Check for existing session asynchronously
        Task { @MainActor in
            await checkExistingSession()
        }
    }

    func stop() {
        logger.info("🔐 AuthService stopped")
    }

    func reset() {
        Task { @MainActor in
            clearAuthState()
        }
        logger.info("🔐 AuthService reset")
    }

    // MARK: - AuthServiceProtocol Implementation

    func signIn(email: String, password: String) async throws -> AuthResult {
        do {
            let result = try await authProvider.authenticate(
                with: .emailPassword(email: email, password: password)
            )
            await updateAuthState(with: result)
            return result
        } catch {
            throw mapToAppError(error)
        }
    }

    func signInWithApple(
        identityToken: Data,
        authorizationCode: Data,
        fullName: PersonNameComponents?
    ) async throws -> AuthResult {
        do {
            let result = try await authProvider.authenticate(
                with: .appleSignIn(
                    identityToken: identityToken,
                    authorizationCode: authorizationCode,
                    fullName: fullName
                )
            )
            await updateAuthState(with: result)
            return result
        } catch {
            throw mapToAppError(error)
        }
    }

    func signInWithBiometrics() async throws -> AuthResult {
        guard let userId = currentUserId else {
            throw AppError.authentication(.biometricFailed)
        }

        do {
            let result = try await authProvider.authenticate(
                with: .biometric(userId: userId)
            )
            await updateAuthState(with: result)
            return result
        } catch {
            throw mapToAppError(error)
        }
    }

    func signInWithSSO(
        provider: SSOProvider,
        code: String,
        state: String?
    ) async throws -> AuthResult {
        do {
            let result = try await authProvider.authenticate(
                with: .sso(provider: provider, code: code, state: state)
            )
            await updateAuthState(with: result)
            return result
        } catch {
            throw mapToAppError(error)
        }
    }

    func signOut() async throws {
        do {
            try await authProvider.revokeTokens()
            await MainActor.run {
                clearAuthState()
            }
            logger.info("👋 User signed out")
        } catch {
            throw mapToAppError(error)
        }
    }

    func refreshSession() async throws {
        do {
            guard await authProvider.isSessionValid else {
                // Try to refresh token
                let newToken = try await authProvider.refreshToken()
                logger.info("🔄 Session refreshed with new token: \(newToken.prefix(20))...")
                return
            }
            logger.info("✅ Session is still valid")
        } catch {
            throw mapToAppError(error)
        }
    }

    var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    // MARK: - Error Mapping

    /// Maps AuthProviderError to AppError for consistent error handling
    private func mapToAppError(_ error: Error) -> AppError {
        // If already an AppError, return it
        if let appError = error as? AppError {
            return appError
        }

        // Map AuthProviderError to AppError.AuthError
        if let providerError = error as? AuthProviderError {
            switch providerError {
            case .invalidCredentials:
                return .authentication(.invalidCredentials)
            case .accountLocked:
                return .authentication(.accountLocked)
            case .accountDisabled:
                return .authentication(.accountDisabled)
            case .emailNotVerified:
                return .authentication(.emailNotVerified)
            case .mfaRequired:
                return .authentication(.mfaRequired)
            case .tokenExpired:
                return .authentication(.tokenExpired)
            case .tokenInvalid:
                return .authentication(.tokenInvalid)
            case .refreshFailed:
                return .authentication(.refreshFailed)
            case .biometricNotAvailable:
                return .authentication(.biometricNotAvailable)
            case .biometricFailed:
                return .authentication(.biometricFailed)
            case .userCancelled:
                return .authentication(.userCancelled)
            case .networkError:
                return .network(.serverError(0))
            case .providerError(let provider, let message):
                return .authentication(.providerError("\(provider): \(message)"))
            case .configurationError:
                return .service(.configurationError)
            case .unknown(let message):
                return .unknown(message)
            }
        }

        // Fallback for unknown errors
        return .unknown(error.localizedDescription)
    }

    // MARK: - Private Methods

    private func checkExistingSession() async {
        let hasValidTokens = await tokenStorage.hasValidTokens

        if hasValidTokens {
            // Restore session from stored tokens
            if (try? await tokenStorage.getAccessToken()) != nil {
                logger.info("🔐 Restored existing session")
                await MainActor.run {
                    self.isAuthenticated = true
                    // Note: userId would need to be decoded from token in production
                }
            }
        }
    }

    @MainActor
    private func updateAuthState(with result: AuthResult) {
        self.currentAuthResult = result
        self.currentUserId = result.userId
        self.isAuthenticated = true

        // Post notification for other parts of the app
        NotificationCenter.default.post(name: .userDidSignIn, object: nil)
    }

    @MainActor
    private func clearAuthState() {
        self.currentAuthResult = nil
        self.currentUserId = nil
        self.isAuthenticated = false

        // Post notification for other parts of the app
        NotificationCenter.default.post(name: .userDidSignOut, object: nil)
    }
}

// Note: Notification names are defined in AuthenticationNotifications.swift
// - .userDidSignIn
// - .userDidSignOut
