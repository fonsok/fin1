import Foundation

/// Production-safe placeholder auth provider.
/// Fails closed in non-DEBUG builds until a real backend auth provider is wired.
final class FailClosedAuthProvider: AuthProviderProtocol {
    func authenticate(with method: AuthMethod) async throws -> AuthResult {
        throw AuthProviderError.configurationError(message: "No production AuthProvider configured")
    }

    func refreshToken() async throws -> String {
        throw AuthProviderError.configurationError(message: "No production AuthProvider configured")
    }

    func revokeTokens() async throws {
        // No-op: AuthService + tokenStorage is responsible for clearing local tokens.
    }

    var isSessionValid: Bool {
        get async { false }
    }

    var currentAccessToken: String? {
        get async { nil }
    }
}

