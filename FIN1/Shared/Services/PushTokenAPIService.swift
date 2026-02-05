import Foundation

// MARK: - Push Token API Service Protocol

/// Protocol for managing push notification tokens with Parse Server backend
protocol PushTokenAPIServiceProtocol {
    /// Registers a push token for a user
    func registerPushToken(_ token: String, tokenType: PushTokenType, userId: String, deviceId: String?) async throws -> PushToken

    /// Updates an existing push token
    func updatePushToken(_ token: String, tokenType: PushTokenType, userId: String, deviceId: String?) async throws -> PushToken

    /// Deactivates a push token
    func deactivatePushToken(_ token: String, tokenType: PushTokenType, userId: String) async throws

    /// Fetches all active push tokens for a user
    func fetchPushTokens(for userId: String) async throws -> [PushToken]
}

// MARK: - Push Token Type

/// Enum representing different push token types
enum PushTokenType: String, Codable {
    case apns = "apns"
    case apnsSandbox = "apns_sandbox"
    case fcm = "fcm"
    case webPush = "web_push"
}

// MARK: - Push Token Model

/// Model representing a push notification token
struct PushToken: Identifiable, Codable, Sendable {
    let id: String // objectId from Parse
    let userId: String
    let token: String
    let tokenType: PushTokenType
    let deviceId: String?
    let isActive: Bool
    let lastValidatedAt: Date?
    let validationFailures: Int
    let createdAt: Date
    let updatedAt: Date?
}

// MARK: - Parse Push Token Input

/// Input struct for creating/updating push tokens on Parse Server
private struct ParsePushTokenInput: Encodable {
    let userId: String
    let token: String
    let tokenType: String
    let deviceId: String?
    let isActive: Bool

    static func from(pushToken: PushToken) -> ParsePushTokenInput {
        return ParsePushTokenInput(
            userId: pushToken.userId,
            token: pushToken.token,
            tokenType: pushToken.tokenType.rawValue,
            deviceId: pushToken.deviceId,
            isActive: pushToken.isActive
        )
    }
}

// MARK: - Parse Push Token Response

/// Response struct for Parse Server push token operations
private struct ParsePushTokenResponse: Codable {
    let objectId: String
    let userId: String
    let token: String
    let tokenType: String
    let deviceId: String?
    let isActive: Bool
    let lastValidatedAt: String?
    let validationFailures: Int
    let createdAt: String
    let updatedAt: String?

    func toPushToken() throws -> PushToken {
        let dateFormatter = ISO8601DateFormatter()

        guard let tokenType = PushTokenType(rawValue: tokenType) else {
            throw PushTokenAPIServiceError.invalidTokenType
        }

        return PushToken(
            id: objectId,
            userId: userId,
            token: token,
            tokenType: tokenType,
            deviceId: deviceId,
            isActive: isActive,
            lastValidatedAt: lastValidatedAt.flatMap { dateFormatter.date(from: $0) },
            validationFailures: validationFailures,
            createdAt: dateFormatter.date(from: createdAt) ?? Date(),
            updatedAt: updatedAt.flatMap { dateFormatter.date(from: $0) }
        )
    }
}

// MARK: - Push Token API Service Error

enum PushTokenAPIServiceError: LocalizedError {
    case invalidTokenType

    var errorDescription: String? {
        switch self {
        case .invalidTokenType:
            return "Invalid push token type"
        }
    }
}

// MARK: - Push Token API Service Implementation

final class PushTokenAPIService: PushTokenAPIServiceProtocol {
    private let apiClient: ParseAPIClientProtocol
    private let className = "PushToken"

    init(apiClient: ParseAPIClientProtocol) {
        self.apiClient = apiClient
    }

    func registerPushToken(_ token: String, tokenType: PushTokenType, userId: String, deviceId: String? = nil) async throws -> PushToken {
        let input = ParsePushTokenInput(
            userId: userId,
            token: token,
            tokenType: tokenType.rawValue,
            deviceId: deviceId,
            isActive: true
        )

        // Check if token already exists
        let existingTokens = try await fetchPushTokens(for: userId)
        if existingTokens.contains(where: { $0.token == token && $0.tokenType == tokenType }) {
            // Update existing token to active
            return try await updatePushToken(token, tokenType: tokenType, userId: userId, deviceId: deviceId)
        }

        // Create new token
        let response: ParseResponse = try await apiClient.createObject(
            className: className,
            object: input
        )

        // Construct PushToken from response
        return PushToken(
            id: response.objectId,
            userId: userId,
            token: token,
            tokenType: tokenType,
            deviceId: deviceId,
            isActive: true,
            lastValidatedAt: nil,
            validationFailures: 0,
            createdAt: Date(),
            updatedAt: nil
        )
    }

    func updatePushToken(_ token: String, tokenType: PushTokenType, userId: String, deviceId: String?) async throws -> PushToken {
        // Find existing token
        let existingTokens = try await fetchPushTokens(for: userId)
        guard let existing = existingTokens.first(where: { $0.token == token && $0.tokenType == tokenType }) else {
            // If not found, create new one
            return try await registerPushToken(token, tokenType: tokenType, userId: userId, deviceId: deviceId)
        }

        // Update existing token
        let input = ParsePushTokenInput(
            userId: userId,
            token: token,
            tokenType: tokenType.rawValue,
            deviceId: deviceId,
            isActive: true
        )

        let _: ParseResponse = try await apiClient.updateObject(
            className: className,
            objectId: existing.id,
            object: input
        )

        return PushToken(
            id: existing.id,
            userId: userId,
            token: token,
            tokenType: tokenType,
            deviceId: deviceId,
            isActive: true,
            lastValidatedAt: existing.lastValidatedAt,
            validationFailures: existing.validationFailures,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
    }

    func deactivatePushToken(_ token: String, tokenType: PushTokenType, userId: String) async throws {
        // Find existing token
        let existingTokens = try await fetchPushTokens(for: userId)
        guard let existing = existingTokens.first(where: { $0.token == token && $0.tokenType == tokenType }) else {
            return // Token not found, nothing to deactivate
        }

        // Update token to inactive
        let input = ParsePushTokenInput(
            userId: userId,
            token: token,
            tokenType: tokenType.rawValue,
            deviceId: existing.deviceId,
            isActive: false
        )

        _ = try await apiClient.updateObject(
            className: className,
            objectId: existing.id,
            object: input
        )
    }

    func fetchPushTokens(for userId: String) async throws -> [PushToken] {
        let query: [String: Any] = [
            "userId": userId
        ]

        let responses: [ParsePushTokenResponse] = try await apiClient.fetchObjects(
            className: className,
            query: query,
            include: nil,
            orderBy: nil,
            limit: nil
        )

        return try responses.map { try $0.toPushToken() }
    }
}
