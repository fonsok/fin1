import Foundation

/// Production auth provider backed by Parse Server.
///
/// Uses Parse REST login (`/login`) via `ParseAPIClientProtocol.login(...)`.
/// Stores the Parse session token in `TokenStorageProtocol` so other app services can
/// access an authenticated session without relying on DEBUG-only mocks.
final class ParseAuthProvider: AuthProviderProtocol {
    private let apiClient: ParseAPIClientProtocol
    private let tokenStorage: TokenStorageProtocol

    /// Parse session tokens generally don't have an explicit short TTL, but we still
    /// keep an expiry in storage so `hasValidTokens` can be used consistently.
    private let sessionTtl: TimeInterval

    init(
        apiClient: ParseAPIClientProtocol,
        tokenStorage: TokenStorageProtocol,
        sessionTtl: TimeInterval = 60 * 60 * 24 * 30 // 30 days
    ) {
        self.apiClient = apiClient
        self.tokenStorage = tokenStorage
        self.sessionTtl = sessionTtl
    }

    func authenticate(with method: AuthMethod) async throws -> AuthResult {
        switch method {
        case .emailPassword(let email, let password):
            let normalized = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            do {
                let response = try await apiClient.login(username: normalized, password: password)
                let expiresAt = Date().addingTimeInterval(sessionTtl)

                // Store the session token as both access+refresh token so we can extend expiry
                // without needing a separate refresh endpoint.
                try await tokenStorage.store(
                    accessToken: response.sessionToken,
                    refreshToken: response.sessionToken,
                    idToken: nil,
                    expiresAt: expiresAt
                )

                let fullName: String? = {
                    let first = response.firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let last = response.lastName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let combined = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
                    return combined.isEmpty ? nil : combined
                }()

                return AuthResult(
                    accessToken: response.sessionToken,
                    refreshToken: response.sessionToken,
                    idToken: nil,
                    expiresAt: expiresAt,
                    tokenType: "Parse",
                    userId: response.objectId,
                    email: response.email ?? normalized,
                    fullName: fullName,
                    claims: [
                        "role": response.role as Any,
                        "stableId": response.stableId as Any
                    ],
                    method: method
                )
            } catch {
                // Parse API surfaces errors as NetworkError/AuthError in many places;
                // map them into provider-level errors for AuthService to translate.
                throw AuthProviderError.networkError(underlying: error)
            }

        case .biometric:
            // Biometric is a local re-auth signal; if we still have valid tokens, treat as success.
            guard await tokenStorage.hasValidTokens,
                  let token = try? await tokenStorage.getAccessToken(),
                  let expiresAt = try? await tokenStorage.getExpirationDate()
            else {
                throw AuthProviderError.biometricFailed
            }

            return AuthResult(
                accessToken: token,
                refreshToken: (try? await tokenStorage.getRefreshToken()) ?? nil,
                idToken: (try? await tokenStorage.getIdToken()) ?? nil,
                expiresAt: expiresAt,
                tokenType: "Parse",
                userId: "",
                email: nil,
                fullName: nil,
                claims: nil,
                method: method
            )

        case .refreshToken:
            // Supported via `refreshToken()` API.
            let token = try await refreshToken()
            let expiresAt = (try? await tokenStorage.getExpirationDate()) ?? Date().addingTimeInterval(sessionTtl)
            return AuthResult(
                accessToken: token,
                refreshToken: (try? await tokenStorage.getRefreshToken()) ?? nil,
                idToken: (try? await tokenStorage.getIdToken()) ?? nil,
                expiresAt: expiresAt,
                tokenType: "Parse",
                userId: "",
                email: nil,
                fullName: nil,
                claims: nil,
                method: method
            )

        case .appleSignIn, .sso, .magicLink:
            throw AuthProviderError.configurationError(message: "Auth method not wired for ParseAuthProvider yet")
        }
    }

    func refreshToken() async throws -> String {
        // Parse doesn't provide a standard refresh-token exchange in this codebase.
        // Best-effort: extend expiration while keeping the existing session token.
        guard let token = try await tokenStorage.getRefreshToken(), !token.isEmpty else {
            throw AuthProviderError.refreshFailed
        }

        let newExpiry = Date().addingTimeInterval(sessionTtl)
        try await tokenStorage.store(
            accessToken: token,
            refreshToken: token,
            idToken: nil,
            expiresAt: newExpiry
        )
        return token
    }

    func revokeTokens() async throws {
        try await tokenStorage.clear()
    }

    var isSessionValid: Bool {
        get async { await tokenStorage.hasValidTokens }
    }

    var currentAccessToken: String? {
        get async { try? await tokenStorage.getAccessToken() }
    }
}

