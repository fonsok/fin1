import Foundation
import OSLog
import Security

// MARK: - Token Storage Protocol
/// Protocol for secure token storage
/// Implementations should use Keychain or other secure storage mechanisms
protocol TokenStorageProtocol {
    /// Store authentication tokens securely
    /// - Parameters:
    ///   - accessToken: The access token to store
    ///   - refreshToken: The refresh token to store (optional)
    ///   - idToken: The ID token to store (optional)
    ///   - expiresAt: Token expiration date
    func store(
        accessToken: String,
        refreshToken: String?,
        idToken: String?,
        expiresAt: Date
    ) async throws

    /// Retrieve the stored access token
    /// - Returns: The access token if available and not expired
    func getAccessToken() async throws -> String?

    /// Retrieve the stored refresh token
    /// - Returns: The refresh token if available
    func getRefreshToken() async throws -> String?

    /// Retrieve the stored ID token
    /// - Returns: The ID token if available
    func getIdToken() async throws -> String?

    /// Get the token expiration date
    /// - Returns: The expiration date if available
    func getExpirationDate() async throws -> Date?

    /// Check if stored tokens are valid (not expired)
    var hasValidTokens: Bool { get async }

    /// Clear all stored tokens (sign out)
    func clear() async throws
}

// MARK: - Token Storage Error
enum TokenStorageError: Error, LocalizedError {
    case storeFailed(underlying: Error?)
    case retrieveFailed(underlying: Error?)
    case deleteFailed(underlying: Error?)
    case encodingFailed
    case decodingFailed
    case keychainError(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .storeFailed(let error):
            return "Token speichern fehlgeschlagen: \(error?.localizedDescription ?? "Unbekannter Fehler")"
        case .retrieveFailed(let error):
            return "Token abrufen fehlgeschlagen: \(error?.localizedDescription ?? "Unbekannter Fehler")"
        case .deleteFailed(let error):
            return "Token löschen fehlgeschlagen: \(error?.localizedDescription ?? "Unbekannter Fehler")"
        case .encodingFailed:
            return "Token-Kodierung fehlgeschlagen"
        case .decodingFailed:
            return "Token-Dekodierung fehlgeschlagen"
        case .keychainError(let status):
            return "Keychain-Fehler: \(status)"
        }
    }
}

// MARK: - Keychain Token Storage
/// Secure token storage using iOS Keychain
final class KeychainTokenStorage: TokenStorageProtocol {

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.fin1.app", category: "KeychainTokenStorage")

    // MARK: - Constants

    private enum Keys {
        static let accessToken = "com.fin1.auth.accessToken"
        static let refreshToken = "com.fin1.auth.refreshToken"
        static let idToken = "com.fin1.auth.idToken"
        static let expiresAt = "com.fin1.auth.expiresAt"
    }

    private let serviceName: String
    private let accessGroup: String?

    // MARK: - Initialization

    /// Initialize Keychain storage
    /// - Parameters:
    ///   - serviceName: Keychain service name (default: app bundle ID)
    ///   - accessGroup: Keychain access group for shared storage (optional)
    init(
        serviceName: String = Bundle.main.bundleIdentifier ?? "com.fin1.app",
        accessGroup: String? = nil
    ) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
    }

    // MARK: - TokenStorageProtocol Implementation

    func store(
        accessToken: String,
        refreshToken: String?,
        idToken: String?,
        expiresAt: Date
    ) async throws {
        // Store access token
        try saveToKeychain(key: Keys.accessToken, value: accessToken)

        // Store refresh token if provided
        if let refreshToken = refreshToken {
            try saveToKeychain(key: Keys.refreshToken, value: refreshToken)
        }

        // Store ID token if provided
        if let idToken = idToken {
            try saveToKeychain(key: Keys.idToken, value: idToken)
        }

        // Store expiration date
        let expiresAtString = ISO8601DateFormatter().string(from: expiresAt)
        try saveToKeychain(key: Keys.expiresAt, value: expiresAtString)

        logger.info("🔐 Tokens stored securely in Keychain")
    }

    func getAccessToken() async throws -> String? {
        try loadFromKeychain(key: Keys.accessToken)
    }

    func getRefreshToken() async throws -> String? {
        try loadFromKeychain(key: Keys.refreshToken)
    }

    func getIdToken() async throws -> String? {
        try loadFromKeychain(key: Keys.idToken)
    }

    func getExpirationDate() async throws -> Date? {
        guard let dateString = try loadFromKeychain(key: Keys.expiresAt) else {
            return nil
        }
        return ISO8601DateFormatter().date(from: dateString)
    }

    var hasValidTokens: Bool {
        get async {
            do {
                guard let accessToken = try await getAccessToken(), !accessToken.isEmpty else {
                    return false
                }
                guard let expiresAt = try await getExpirationDate() else {
                    return false
                }
                return Date() < expiresAt
            } catch {
                return false
            }
        }
    }

    func clear() async throws {
        try deleteFromKeychain(key: Keys.accessToken)
        try deleteFromKeychain(key: Keys.refreshToken)
        try deleteFromKeychain(key: Keys.idToken)
        try deleteFromKeychain(key: Keys.expiresAt)
        logger.info("🔐 All tokens cleared from Keychain")
    }

    // MARK: - Keychain Helpers

    private func saveToKeychain(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw TokenStorageError.encodingFailed
        }

        // Delete existing item first
        try? deleteFromKeychain(key: key)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw TokenStorageError.keychainError(status: status)
        }
    }

    private func loadFromKeychain(key: String) throws -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let value = String(data: data, encoding: .utf8) else {
                throw TokenStorageError.decodingFailed
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw TokenStorageError.keychainError(status: status)
        }
    }

    private func deleteFromKeychain(key: String) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokenStorageError.keychainError(status: status)
        }
    }
}

// MARK: - In-Memory Token Storage (for Testing)
#if DEBUG
/// In-memory token storage for testing purposes
final class InMemoryTokenStorage: TokenStorageProtocol {
    private var accessToken: String?
    private var refreshToken: String?
    private var idToken: String?
    private var expiresAt: Date?

    func store(
        accessToken: String,
        refreshToken: String?,
        idToken: String?,
        expiresAt: Date
    ) async throws {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.expiresAt = expiresAt
    }

    func getAccessToken() async throws -> String? { accessToken }
    func getRefreshToken() async throws -> String? { refreshToken }
    func getIdToken() async throws -> String? { idToken }
    func getExpirationDate() async throws -> Date? { expiresAt }

    var hasValidTokens: Bool {
        get async {
            guard let token = accessToken, !token.isEmpty,
                  let expiry = expiresAt else { return false }
            return Date() < expiry
        }
    }

    func clear() async throws {
        accessToken = nil
        refreshToken = nil
        idToken = nil
        expiresAt = nil
    }
}
#endif
