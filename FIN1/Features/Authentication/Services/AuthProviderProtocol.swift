import Foundation

// MARK: - Auth Provider Protocol
/// Abstraction layer for authentication providers (Apple Sign In, Auth0, Okta, etc.)
/// This protocol allows swapping authentication backends without changing app logic.
protocol AuthProviderProtocol {
    /// Authenticate user with the specified method
    /// - Parameter method: The authentication method to use
    /// - Returns: Authentication result containing tokens and user info
    func authenticate(with method: AuthMethod) async throws -> AuthResult

    /// Refresh the current access token
    /// - Returns: New access token
    func refreshToken() async throws -> String

    /// Revoke all tokens and sign out
    func revokeTokens() async throws

    /// Check if the current session is valid
    var isSessionValid: Bool { get async }

    /// Get the current access token (if available)
    var currentAccessToken: String? { get async }
}

// MARK: - Authentication Method
/// Supported authentication methods
enum AuthMethod: Equatable {
    /// Email and password authentication
    case emailPassword(email: String, password: String)

    /// Apple Sign In (ASAuthorization)
    case appleSignIn(identityToken: Data, authorizationCode: Data, fullName: PersonNameComponents?)

    /// Biometric authentication (Face ID / Touch ID) for re-authentication
    case biometric(userId: String)

    /// Single Sign-On (SSO) for enterprise/CSR users
    case sso(provider: SSOProvider, code: String, state: String?)

    /// Magic link authentication (passwordless)
    case magicLink(token: String)

    /// Refresh token authentication
    case refreshToken(token: String)

    var displayName: String {
        switch self {
        case .emailPassword: return "E-Mail & Passwort"
        case .appleSignIn: return "Mit Apple anmelden"
        case .biometric: return "Biometrische Anmeldung"
        case .sso(let provider, _, _): return provider.displayName
        case .magicLink: return "Magic Link"
        case .refreshToken: return "Token-Erneuerung"
        }
    }
}

// MARK: - SSO Provider
/// Supported SSO providers for enterprise authentication
enum SSOProvider: String, Codable, CaseIterable {
    case auth0 = "auth0"
    case okta = "okta"
    case azureAD = "azure_ad"
    case google = "google_workspace"

    var displayName: String {
        switch self {
        case .auth0: return "Auth0"
        case .okta: return "Okta"
        case .azureAD: return "Microsoft Azure AD"
        case .google: return "Google Workspace"
        }
    }

    var authorizationURL: String {
        switch self {
        case .auth0: return "https://YOUR_DOMAIN.auth0.com/authorize"
        case .okta: return "https://YOUR_DOMAIN.okta.com/oauth2/default/v1/authorize"
        case .azureAD: return "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"
        case .google: return "https://accounts.google.com/o/oauth2/v2/auth"
        }
    }
}

// MARK: - Authentication Result
/// Result of a successful authentication
struct AuthResult: Equatable {
    /// Access token for API calls
    let accessToken: String

    /// Refresh token for obtaining new access tokens
    let refreshToken: String?

    /// ID token containing user claims (JWT)
    let idToken: String?

    /// Token expiration date
    let expiresAt: Date

    /// Token type (usually "Bearer")
    let tokenType: String

    /// User identifier from the auth provider
    let userId: String

    /// User email (if available)
    let email: String?

    /// User's full name (if available)
    let fullName: String?

    /// Additional claims from the token
    let claims: [String: Any]?

    /// The authentication method used
    let method: AuthMethod

    init(
        accessToken: String,
        refreshToken: String? = nil,
        idToken: String? = nil,
        expiresAt: Date,
        tokenType: String = "Bearer",
        userId: String,
        email: String? = nil,
        fullName: String? = nil,
        claims: [String: Any]? = nil,
        method: AuthMethod
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.expiresAt = expiresAt
        self.tokenType = tokenType
        self.userId = userId
        self.email = email
        self.fullName = fullName
        self.claims = claims
        self.method = method
    }

    /// Check if the token is expired
    var isExpired: Bool {
        Date() >= expiresAt
    }

    /// Check if the token will expire soon (within 5 minutes)
    var willExpireSoon: Bool {
        Date().addingTimeInterval(300) >= expiresAt
    }

    // MARK: - Equatable (excluding claims)

    static func == (lhs: AuthResult, rhs: AuthResult) -> Bool {
        lhs.accessToken == rhs.accessToken &&
        lhs.refreshToken == rhs.refreshToken &&
        lhs.idToken == rhs.idToken &&
        lhs.expiresAt == rhs.expiresAt &&
        lhs.tokenType == rhs.tokenType &&
        lhs.userId == rhs.userId &&
        lhs.email == rhs.email &&
        lhs.fullName == rhs.fullName &&
        lhs.method == rhs.method
    }
}

// MARK: - Authentication Provider Error
/// Errors that can occur during authentication with providers
enum AuthProviderError: Error, LocalizedError {
    case invalidCredentials
    case accountLocked(until: Date?)
    case accountDisabled
    case emailNotVerified
    case mfaRequired(challenge: MFAChallenge)
    case tokenExpired
    case tokenInvalid
    case refreshFailed
    case networkError(underlying: Error)
    case providerError(provider: String, message: String)
    case biometricNotAvailable
    case biometricFailed
    case userCancelled
    case configurationError(message: String)
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Ungültige Anmeldedaten. Bitte überprüfen Sie E-Mail und Passwort."
        case .accountLocked(let until):
            if let until = until {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                return "Konto gesperrt bis \(formatter.string(from: until))."
            }
            return "Konto vorübergehend gesperrt. Bitte versuchen Sie es später erneut."
        case .accountDisabled:
            return "Dieses Konto wurde deaktiviert. Bitte kontaktieren Sie den Support."
        case .emailNotVerified:
            return "Bitte bestätigen Sie Ihre E-Mail-Adresse, bevor Sie sich anmelden."
        case .mfaRequired:
            return "Zwei-Faktor-Authentifizierung erforderlich."
        case .tokenExpired:
            return "Ihre Sitzung ist abgelaufen. Bitte melden Sie sich erneut an."
        case .tokenInvalid:
            return "Ungültiges Authentifizierungstoken."
        case .refreshFailed:
            return "Token-Erneuerung fehlgeschlagen. Bitte melden Sie sich erneut an."
        case .networkError:
            return "Netzwerkfehler. Bitte überprüfen Sie Ihre Internetverbindung."
        case .providerError(let provider, let message):
            return "\(provider)-Fehler: \(message)"
        case .biometricNotAvailable:
            return "Biometrische Authentifizierung ist auf diesem Gerät nicht verfügbar."
        case .biometricFailed:
            return "Biometrische Authentifizierung fehlgeschlagen."
        case .userCancelled:
            return "Anmeldung abgebrochen."
        case .configurationError(let message):
            return "Konfigurationsfehler: \(message)"
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - MFA Challenge
/// Multi-Factor Authentication challenge
struct MFAChallenge: Equatable {
    let challengeId: String
    let type: MFAType
    let hint: String?  // e.g., "***@example.com" or "+49 *** *** 89"

    enum MFAType: String, Codable {
        case sms = "sms"
        case email = "email"
        case totp = "totp"  // Time-based One-Time Password (Authenticator App)
        case push = "push"  // Push notification
    }
}
