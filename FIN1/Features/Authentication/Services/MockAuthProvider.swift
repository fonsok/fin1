import Foundation
import OSLog

// MARK: - Mock Auth Provider
/// Mock authentication provider for development and testing
/// This provider simulates authentication without requiring a real backend
@MainActor
final class MockAuthProvider: AuthProviderProtocol {

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.fin1.app", category: "MockAuthProvider")

    // MARK: - Properties

    private let tokenStorage: TokenStorageProtocol
    private var simulatedDelay: UInt64 = 1_000_000_000 // 1 second

    /// Simulated user database for testing
    private let testUsers: [String: TestUserCredentials] = [
        // 5 Investors (ANL-)
        "investor1@test.com": TestUserCredentials(password: TestConstants.password, userId: "inv-001", role: "investor"),
        "investor2@test.com": TestUserCredentials(password: TestConstants.password, userId: "inv-002", role: "investor"),
        "investor3@test.com": TestUserCredentials(password: TestConstants.password, userId: "inv-003", role: "investor"),
        "investor4@test.com": TestUserCredentials(password: TestConstants.password, userId: "inv-004", role: "investor"),
        "investor5@test.com": TestUserCredentials(password: TestConstants.password, userId: "inv-005", role: "investor"),
        // 10 Traders (TRD-)
        "trader1@test.com": TestUserCredentials(password: TestConstants.password, userId: "trd-001", role: "trader"),
        "trader2@test.com": TestUserCredentials(password: TestConstants.password, userId: "trd-002", role: "trader"),
        "trader3@test.com": TestUserCredentials(password: TestConstants.password, userId: "trd-003", role: "trader"),
        "trader4@test.com": TestUserCredentials(password: TestConstants.password, userId: "trd-004", role: "trader"),
        "trader5@test.com": TestUserCredentials(password: TestConstants.password, userId: "trd-005", role: "trader"),
        "trader6@test.com": TestUserCredentials(password: TestConstants.password, userId: "trd-006", role: "trader"),
        "trader7@test.com": TestUserCredentials(password: TestConstants.password, userId: "trd-007", role: "trader"),
        "trader8@test.com": TestUserCredentials(password: TestConstants.password, userId: "trd-008", role: "trader"),
        "trader9@test.com": TestUserCredentials(password: TestConstants.password, userId: "trd-009", role: "trader"),
        "trader10@test.com": TestUserCredentials(password: TestConstants.password, userId: "trd-010", role: "trader"),
        // Admin
        "admin@test.com": TestUserCredentials(password: TestConstants.password, userId: "adm-001", role: "admin"),
        // CSR Roles
        "csr-l1@test.com": TestUserCredentials(password: TestConstants.password, userId: "csr-l1-001", role: "csr-l1"),
        "csr-l2@test.com": TestUserCredentials(password: TestConstants.password, userId: "csr-l2-001", role: "csr-l2"),
        "csr-fraud@test.com": TestUserCredentials(password: TestConstants.password, userId: "csr-fraud-001", role: "csr-fraud"),
        "csr-compliance@test.com": TestUserCredentials(password: TestConstants.password, userId: "csr-compl-001", role: "csr-compliance"),
        "csr-tech-support@test.com": TestUserCredentials(password: TestConstants.password, userId: "csr-tech-001", role: "csr-tech"),
        "csr-teamlead@test.com": TestUserCredentials(password: TestConstants.password, userId: "csr-lead-001", role: "csr-teamlead")
    ]

    // MARK: - Initialization

    init(tokenStorage: TokenStorageProtocol) {
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
        try await Task.sleep(nanoseconds: self.simulatedDelay)

        switch method {
        case .emailPassword(let email, let password):
            return try await self.authenticateWithEmailPassword(email: email, password: password)

        case .appleSignIn(let identityToken, _, let fullName):
            return try await self.authenticateWithApple(identityToken: identityToken, fullName: fullName)

        case .biometric(let userId):
            return try await self.authenticateWithBiometric(userId: userId)

        case .sso(let provider, let code, _):
            return try await self.authenticateWithSSO(provider: provider, code: code)

        case .magicLink(let token):
            return try await self.authenticateWithMagicLink(token: token)

        case .refreshToken(let token):
            return try await self.authenticateWithRefreshToken(token: token)
        }
    }

    func refreshToken() async throws -> String {
        try await Task.sleep(nanoseconds: self.simulatedDelay / 2)

        guard (try await self.tokenStorage.getRefreshToken()) != nil else {
            throw AuthProviderError.refreshFailed
        }

        // Generate new tokens
        let newAccessToken = self.generateMockToken(prefix: "mock_access")
        let newRefreshToken = self.generateMockToken(prefix: "mock_refresh")
        let expiresAt = Date().addingTimeInterval(3_600) // 1 hour

        try await self.tokenStorage.store(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
            idToken: nil,
            expiresAt: expiresAt
        )

        self.logger.info("🔄 Token refreshed successfully")
        return newAccessToken
    }

    func revokeTokens() async throws {
        try await Task.sleep(nanoseconds: self.simulatedDelay / 4)
        try await self.tokenStorage.clear()
        self.logger.info("🔐 Tokens revoked")
    }

    var isSessionValid: Bool {
        get async {
            await self.tokenStorage.hasValidTokens
        }
    }

    var currentAccessToken: String? {
        get async {
            try? await self.tokenStorage.getAccessToken()
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
            return try await self.createAuthResult(
                userId: testUser.userId,
                email: normalizedEmail,
                fullName: nil,
                method: .emailPassword(email: email, password: password)
            )
        }

        // Allow any email with pattern matching for flexible testing
        if normalizedEmail.contains("test") || normalizedEmail.contains("@test.com") {
            return try await self.createAuthResult(
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

        return try await self.createAuthResult(
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

        return try await self.createAuthResult(
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

        return try await self.createAuthResult(
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

        return try await self.createAuthResult(
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

        return try await self.createAuthResult(
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
        let accessToken = self.generateMockToken(prefix: "mock_access")
        let refreshToken = self.generateMockToken(prefix: "mock_refresh")
        let idToken = self.generateMockToken(prefix: "mock_id")
        let expiresAt = Date().addingTimeInterval(3_600) // 1 hour

        // Store tokens
        try await self.tokenStorage.store(
            accessToken: accessToken,
            refreshToken: refreshToken,
            idToken: idToken,
            expiresAt: expiresAt
        )

        self.logger.info("✅ Mock authentication successful for user: \(userId)")

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
