import XCTest
@testable import FIN1

// MARK: - Push Token API Service Tests

final class PushTokenAPIServiceTests: XCTestCase {

    var sut: PushTokenAPIService!
    var mockAPIClient: MockParseAPIClient!

    override func setUp() {
        super.setUp()
        mockAPIClient = MockParseAPIClient()
        sut = PushTokenAPIService(apiClient: mockAPIClient)
    }

    override func tearDown() {
        sut = nil
        mockAPIClient = nil
        super.tearDown()
    }

    // MARK: - Register Push Token Tests

    func testRegisterPushToken_Success_NewToken() async throws {
        // Given
        let token = "apns-token-abc123"
        let tokenType = PushTokenType.apns
        let userId = "test-user-123"
        let deviceId = "iPhone-14-test"
        mockAPIClient.mockObjectId = "server-push-token-id"
        mockAPIClient.mockFetchResults = [ParsePushTokenResponse]() // No existing tokens

        // When
        let savedToken = try await sut.registerPushToken(token, tokenType: tokenType, userId: userId, deviceId: deviceId)

        // Then
        XCTAssertTrue(mockAPIClient.createObjectCalled)
        XCTAssertEqual(mockAPIClient.lastClassName, "PushToken")
        XCTAssertEqual(savedToken.id, "server-push-token-id")
        XCTAssertEqual(savedToken.token, token)
        XCTAssertEqual(savedToken.tokenType, tokenType)
        XCTAssertEqual(savedToken.userId, userId)
        XCTAssertTrue(savedToken.isActive)
    }

    func testRegisterPushToken_Success_ExistingToken() async throws {
        // Given
        let token = "apns-token-existing"
        let tokenType = PushTokenType.apns
        let userId = "test-user-123"
        let existingToken = createMockPushTokenResponse(objectId: "existing-id", token: token)
        mockAPIClient.mockFetchResults = [existingToken]

        // When
        let savedToken = try await sut.registerPushToken(token, tokenType: tokenType, userId: userId, deviceId: nil)

        // Then
        XCTAssertTrue(mockAPIClient.updateObjectCalled)
        XCTAssertEqual(savedToken.token, token)
    }

    func testRegisterPushToken_NetworkError() async {
        // Given
        let token = "apns-token-error"
        mockAPIClient.shouldThrowError = true
        mockAPIClient.errorToThrow = NetworkError.noConnection

        // When/Then
        do {
            _ = try await sut.registerPushToken(token, tokenType: .apns, userId: "test-user", deviceId: nil)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }

    // MARK: - Update Push Token Tests

    func testUpdatePushToken_Success() async throws {
        // Given
        let token = "apns-token-to-update"
        let tokenType = PushTokenType.apns
        let userId = "test-user-123"
        let existingToken = createMockPushTokenResponse(objectId: "existing-id", token: token)
        mockAPIClient.mockFetchResults = [existingToken]

        // When
        let updatedToken = try await sut.updatePushToken(token, tokenType: tokenType, userId: userId, deviceId: "new-device-id")

        // Then
        XCTAssertTrue(mockAPIClient.updateObjectCalled)
        XCTAssertEqual(mockAPIClient.lastClassName, "PushToken")
        XCTAssertEqual(mockAPIClient.lastObjectId, "existing-id")
        XCTAssertEqual(updatedToken.token, token)
    }

    func testUpdatePushToken_NotFound_CreatesNew() async throws {
        // Given
        let token = "apns-token-new"
        let tokenType = PushTokenType.apns
        let userId = "test-user-123"
        mockAPIClient.mockFetchResults = [ParsePushTokenResponse]() // No existing tokens
        mockAPIClient.mockObjectId = "new-token-id"

        // When
        let savedToken = try await sut.updatePushToken(token, tokenType: tokenType, userId: userId, deviceId: nil)

        // Then
        XCTAssertTrue(mockAPIClient.createObjectCalled)
        XCTAssertEqual(savedToken.id, "new-token-id")
    }

    // MARK: - Deactivate Push Token Tests

    func testDeactivatePushToken_Success() async throws {
        // Given
        let token = "apns-token-to-deactivate"
        let tokenType = PushTokenType.apns
        let userId = "test-user-123"
        let existingToken = createMockPushTokenResponse(objectId: "existing-id", token: token)
        mockAPIClient.mockFetchResults = [existingToken]

        // When
        try await sut.deactivatePushToken(token, tokenType: tokenType, userId: userId)

        // Then
        XCTAssertTrue(mockAPIClient.updateObjectCalled)
        XCTAssertEqual(mockAPIClient.lastObjectId, "existing-id")
    }

    func testDeactivatePushToken_NotFound_NoError() async throws {
        // Given
        let token = "apns-token-not-found"
        let tokenType = PushTokenType.apns
        let userId = "test-user-123"
        mockAPIClient.mockFetchResults = [ParsePushTokenResponse]() // No tokens

        // When/Then - Should not throw
        try await sut.deactivatePushToken(token, tokenType: tokenType, userId: userId)
        XCTAssertFalse(mockAPIClient.updateObjectCalled)
    }

    // MARK: - Fetch Push Tokens Tests

    func testFetchPushTokens_Success() async throws {
        // Given
        let userId = "test-user-123"
        let mockTokens = [
            createMockPushTokenResponse(objectId: "token-1", token: "apns-token-1"),
            createMockPushTokenResponse(objectId: "token-2", token: "fcm-token-1", tokenType: "fcm")
        ]
        mockAPIClient.mockFetchResults = mockTokens

        // When
        let tokens = try await sut.fetchPushTokens(for: userId)

        // Then
        XCTAssertTrue(mockAPIClient.fetchObjectsCalled)
        XCTAssertEqual(mockAPIClient.lastClassName, "PushToken")
        XCTAssertEqual(tokens.count, 2)
    }

    func testFetchPushTokens_EmptyResult() async throws {
        // Given
        let userId = "test-user-no-tokens"
        mockAPIClient.mockFetchResults = [ParsePushTokenResponse]()

        // When
        let tokens = try await sut.fetchPushTokens(for: userId)

        // Then
        XCTAssertTrue(mockAPIClient.fetchObjectsCalled)
        XCTAssertTrue(tokens.isEmpty)
    }

    // MARK: - Helper Methods

    private func createMockPushTokenResponse(
        objectId: String,
        token: String,
        tokenType: String = "apns",
        isActive: Bool = true
    ) -> ParsePushTokenResponse {
        ParsePushTokenResponse(
            objectId: objectId,
            userId: "test-user-123",
            token: token,
            tokenType: tokenType,
            deviceId: "test-device",
            isActive: isActive,
            lastValidatedAt: nil,
            validationFailures: 0,
            createdAt: "2026-02-05T10:00:00.000Z",
            updatedAt: "2026-02-05T10:00:00.000Z"
        )
    }
}
