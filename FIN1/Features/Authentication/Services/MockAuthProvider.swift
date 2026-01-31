import Foundation
import OSLog

#if DEBUG
// MARK: - Mock Auth Provider
/// Mock authentication provider for development and testing
/// This provider simulates authentication without requiring a real backend
final class MockAuthProvider: AuthProviderProtocol {

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.fin1.app", category: "MockAuthProvider")

    // MARK: - Properties

    private let tokenStorage: TokenStorageProtocol
    private var simulatedDelay: UInt64 = 1_000_000_000 // 1 second

    /// Simulated user database for testing
    private let testUsers: [String: TestUserCredentials] = [
        // Investors
        "investor1@test.com": TestUserCredentials(password: "Password123!", userId: "inv-001", role: "investor"),
        "investor2@test.com": TestUserCredentials(password: "Password123!", userId: "inv-002", role: "investor"),
        "investor3@test.com": TestUserCredentials(password: "Password123!", userId: "inv-003", role: "investor"),
        // Traders
        "trader1@test.com": TestUserCredentials(password: "Password123!", userId: "trd-001", role: "trader"),
        "trader2@test.com": TestUserCredentials(password: "Password123!", userId: "trd-002", role: "trader"),
        // Admin
        "admin@test.com": TestUserCredentials(password: "Password123!", userId: "adm-001", role: "admin"),
        // CSR Roles
        "csr-l1@test.com": TestUserCredentials(password: "Password123!", userId: "csr-l1-001", role: "csr-l1"),
        "csr-l2@test.com": TestUserCredentials(password: "Password123!", userId: "csr-l2-001", role: "csr-l2"),
        "csr-fraud@test.com": TestUserCredentials(password: "Password123!", userId: "csr-fraud-001", role: "csr-fraud"),
        "csr-compliance@test.com": TestUserCredentials(password: "Password123!", userId: "csr-compl-001", role: "csr-compliance"),
        "csr-tech-support@test.com": TestUserCredentials(password: "Password123!", userId: "csr-tech-001", role: "csr-tech"),
        "csr-teamlead@test.com": TestUserCredentials(password: "Password123!", userId: "csr-lead-001", role: "csr-teamlead")
    ]

    // MARK: - Initialization

    init(tokenStorage: TokenStorageProtocol = InMemoryTokenStorage()) {
        self.tokenStorage = tokenStorage
    }

    // MARK: - Configuration

    /// Set simulated network delay (in nanoseconds)
    func setSimulatedDelay(_ nanoseconds: UInt64) {
        self.simulatedDelay = nanoseconds
    }

    // MARK: - AuthProviderProtocol Implementation

    func authenticate(with method: AuthMethod) async throws -> AuthResult {
        // Simulate network delay
        try await Task.sleep(nanoseconds: simulatedDelay)

        switch method {
        case .emailPassword(let email, let password):
            return try await authenticateWithEmailPassword(email: email, password: password)

        case .appleSignIn(let identityToken, _, let fullName):
            return try await authenticateWithApple(identityToken: identityToken, fullName: fullName)

        case .biometric(let userId):
            return try await authenticateWithBiometric(userId: userId)

        case .sso(let provider, let code, _):
            return try await authenticateWithSSO(provider: provider, code: code)

        case .magicLink(let token):
            return try await authenticateWithMagicLink(token: token)

        case .refreshToken(let token):
            return try await authenticateWithRefreshToken(token: token)
        }
    }

    func refreshToken() async throws -> String {
        try await Task.sleep(nanoseconds: simulatedDelay / 2)

        guard (try await tokenStorage.getRefreshToken()) != nil else {
            throw AuthProviderError.refreshFailed
        }

        // Generate new tokens
        let newAccessToken = generateMockToken(prefix: "mock_access")
        let newRefreshToken = generateMockToken(prefix: "mock_refresh")
        let expiresAt = Date().addingTimeInterval(3600) // 1 hour

        try await tokenStorage.store(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
            idToken: nil,
            expiresAt: expiresAt
        )

        logger.info("🔄 Token refreshed successfully")
        return newAccessToken
    }

    func revokeTokens() async throws {
        try await Task.sleep(nanoseconds: simulatedDelay / 4)
        try await tokenStorage.clear()
        logger.info("🔐 Tokens revoked")
    }

    var isSessionValid: Bool {
        get async {
            await tokenStorage.hasValidTokens
        }
    }

    var currentAccessToken: String? {
        get async {
            try? await tokenStorage.getAccessToken()
        }
    }

    // MARK: - Private Authentication Methods

    private func authenticateWithEmailPassword(email: String, password: String) async throws -> AuthResult {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)

        // Check for test user
        if let testUser = testUsers[normalizedEmail] {
            guard testUser.password == password else {
                throw AuthProviderError.invalidCredentials
            }
            return try await createAuthResult(
                userId: testUser.userId,
                email: normalizedEmail,
                fullName: nil,
                method: .emailPassword(email: email, password: password)
            )
        }

        // Allow any email with pattern matching for flexible testing
        if normalizedEmail.contains("test") || normalizedEmail.contains("@test.com") {
            return try await createAuthResult(
                userId: "user-\(UUID().uuidString.prefix(8))",
                email: normalizedEmail,
                fullName: nil,
                method: .emailPassword(email: email, password: password)
            )
        }

        throw AuthProviderError.invalidCredentials
    }

    private func authenticateWithApple(identityToken: Data, fullName: PersonNameComponents?) async throws -> AuthResult {
        // In production, validate the identityToken with Apple's servers
        // For mock, we'll simulate a successful authentication

        let userId = "apple-\(UUID().uuidString.prefix(8))"
        var name: String?

        if let fullName = fullName {
            let formatter = PersonNameComponentsFormatter()
            name = formatter.string(from: fullName)
        }

        return try await createAuthResult(
            userId: userId,
            email: nil,
            fullName: name,
            method: .appleSignIn(identityToken: identityToken, authorizationCode: Data(), fullName: fullName)
        )
    }

    private func authenticateWithBiometric(userId: String) async throws -> AuthResult {
        // In production, verify biometric with LocalAuthentication
        // For mock, we'll check if we have a valid refresh token

        let hasValidTokens = await tokenStorage.hasValidTokens
        let hasRefreshToken = (try? await tokenStorage.getRefreshToken()) != nil

        guard hasValidTokens || hasRefreshToken else {
            throw AuthProviderError.biometricFailed
        }

        return try await createAuthResult(
            userId: userId,
            email: nil,
            fullName: nil,
            method: .biometric(userId: userId)
        )
    }

    private func authenticateWithSSO(provider: SSOProvider, code: String) async throws -> AuthResult {
        // In production, exchange the code for tokens with the SSO provider
        // For mock, we'll simulate a successful authentication

        let userId = "\(provider.rawValue)-\(UUID().uuidString.prefix(8))"

        return try await createAuthResult(
            userId: userId,
            email: "sso-user@\(provider.rawValue).com",
            fullName: "SSO User",
            method: .sso(provider: provider, code: code, state: nil)
        )
    }

    private func authenticateWithMagicLink(token: String) async throws -> AuthResult {
        // In production, validate the magic link token
        // For mock, we'll simulate a successful authentication

        let userId = "magic-\(UUID().uuidString.prefix(8))"

        return try await createAuthResult(
            userId: userId,
            email: "user@magiclink.test",
            fullName: nil,
            method: .magicLink(token: token)
        )
    }

    private func authenticateWithRefreshToken(token: String) async throws -> AuthResult {
        // Validate refresh token and issue new tokens
        guard !token.isEmpty else {
            throw AuthProviderError.tokenInvalid
        }

        let userId = "refreshed-\(UUID().uuidString.prefix(8))"

        return try await createAuthResult(
            userId: userId,
            email: nil,
            fullName: nil,
            method: .refreshToken(token: token)
        )
    }

    // MARK: - Helper Methods

    private func createAuthResult(
        userId: String,
        email: String?,
        fullName: String?,
        method: AuthMethod
    ) async throws -> AuthResult {
        let accessToken = generateMockToken(prefix: "mock_access")
        let refreshToken = generateMockToken(prefix: "mock_refresh")
        let idToken = generateMockToken(prefix: "mock_id")
        let expiresAt = Date().addingTimeInterval(3600) // 1 hour

        // Store tokens
        try await tokenStorage.store(
            accessToken: accessToken,
            refreshToken: refreshToken,
            idToken: idToken,
            expiresAt: expiresAt
        )

        logger.info("✅ Mock authentication successful for user: \(userId)")

        return AuthResult(
            accessToken: accessToken,
            refreshToken: refreshToken,
            idToken: idToken,
            expiresAt: expiresAt,
            tokenType: "Bearer",
            userId: userId,
            email: email,
            fullName: fullName,
            claims: ["provider": "mock", "environment": "development"],
            method: method
        )
    }

    private func generateMockToken(prefix: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return "\(prefix)_\(timestamp)_\(random)"
    }
}

// MARK: - Test User Credentials

private struct TestUserCredentials {
    let password: String
    let userId: String
    let role: String
}
#endif
