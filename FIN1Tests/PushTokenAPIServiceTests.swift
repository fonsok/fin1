@testable import FIN1
import XCTest

// MARK: - Push Token API Service Tests

final class PushTokenAPIServiceTests: XCTestCase {

    var sut: PushTokenAPIService!
    var mockAPIClient: MockParseAPIClient!

    override func setUp() {
        super.setUp()
        self.mockAPIClient = MockParseAPIClient()
        self.sut = PushTokenAPIService(apiClient: self.mockAPIClient)
    }

    override func tearDown() {
        self.sut = nil
        self.mockAPIClient = nil
        super.tearDown()
    }

    // MARK: - Register Push Token Tests

    func testRegisterPushToken_Success_NewToken() async throws {
        // Given
        let token = "apns-token-abc123"
        let tokenType = PushTokenType.apns
        let userId = "test-user-123"
        let deviceId = "iPhone-14-test"
        self.mockAPIClient.mockObjectId = "server-push-token-id"
        self.mockAPIClient.mockFetchResults = [ParsePushTokenResponse]() // No existing tokens

        // When
        let savedToken = try await sut.registerPushToken(token, tokenType: tokenType, userId: userId, deviceId: deviceId)

        // Then
        XCTAssertTrue(self.mockAPIClient.createObjectCalled)
        XCTAssertEqual(self.mockAPIClient.lastClassName, "PushToken")
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
        let existingToken = self.createMockPushTokenResponse(objectId: "existing-id", token: token)
        self.mockAPIClient.mockFetchResults = [existingToken]

        // When
        let savedToken = try await sut.registerPushToken(token, tokenType: tokenType, userId: userId, deviceId: nil)

        // Then
        XCTAssertTrue(self.mockAPIClient.updateObjectCalled)
        XCTAssertEqual(savedToken.token, token)
    }

    func testRegisterPushToken_NetworkError() async {
        // Given
        let token = "apns-token-error"
        self.mockAPIClient.shouldThrowError = true
        self.mockAPIClient.errorToThrow = NetworkError.noConnection

        // When/Then
        do {
            _ = try await self.sut.registerPushToken(token, tokenType: .apns, userId: "test-user", deviceId: nil)
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
        let existingToken = self.createMockPushTokenResponse(objectId: "existing-id", token: token)
        self.mockAPIClient.mockFetchResults = [existingToken]

        // When
        let updatedToken = try await sut.updatePushToken(token, tokenType: tokenType, userId: userId, deviceId: "new-device-id")

        // Then
        XCTAssertTrue(self.mockAPIClient.updateObjectCalled)
        XCTAssertEqual(self.mockAPIClient.lastClassName, "PushToken")
        XCTAssertEqual(self.mockAPIClient.lastObjectId, "existing-id")
        XCTAssertEqual(updatedToken.token, token)
    }

    func testUpdatePushToken_NotFound_CreatesNew() async throws {
        // Given
        let token = "apns-token-new"
        let tokenType = PushTokenType.apns
        let userId = "test-user-123"
        self.mockAPIClient.mockFetchResults = [ParsePushTokenResponse]() // No existing tokens
        self.mockAPIClient.mockObjectId = "new-token-id"

        // When
        let savedToken = try await sut.updatePushToken(token, tokenType: tokenType, userId: userId, deviceId: nil)

        // Then
        XCTAssertTrue(self.mockAPIClient.createObjectCalled)
        XCTAssertEqual(savedToken.id, "new-token-id")
    }

    // MARK: - Deactivate Push Token Tests

    func testDeactivatePushToken_Success() async throws {
        // Given
        let token = "apns-token-to-deactivate"
        let tokenType = PushTokenType.apns
        let userId = "test-user-123"
        let existingToken = self.createMockPushTokenResponse(objectId: "existing-id", token: token)
        self.mockAPIClient.mockFetchResults = [existingToken]

        // When
        try await self.sut.deactivatePushToken(token, tokenType: tokenType, userId: userId)

        // Then
        XCTAssertTrue(self.mockAPIClient.updateObjectCalled)
        XCTAssertEqual(self.mockAPIClient.lastObjectId, "existing-id")
    }

    func testDeactivatePushToken_NotFound_NoError() async throws {
        // Given
        let token = "apns-token-not-found"
        let tokenType = PushTokenType.apns
        let userId = "test-user-123"
        self.mockAPIClient.mockFetchResults = [ParsePushTokenResponse]() // No tokens

        // When/Then - Should not throw
        try await self.sut.deactivatePushToken(token, tokenType: tokenType, userId: userId)
        XCTAssertFalse(self.mockAPIClient.updateObjectCalled)
    }

    // MARK: - Fetch Push Tokens Tests

    func testFetchPushTokens_Success() async throws {
        // Given
        let userId = "test-user-123"
        let mockTokens = [
            createMockPushTokenResponse(objectId: "token-1", token: "apns-token-1"),
            createMockPushTokenResponse(objectId: "token-2", token: "fcm-token-1", tokenType: "fcm")
        ]
        self.mockAPIClient.mockFetchResults = mockTokens

        // When
        let tokens = try await sut.fetchPushTokens(for: userId)

        // Then
        XCTAssertTrue(self.mockAPIClient.fetchObjectsCalled)
        XCTAssertEqual(self.mockAPIClient.lastClassName, "PushToken")
        XCTAssertEqual(tokens.count, 2)
    }

    func testFetchPushTokens_EmptyResult() async throws {
        // Given
        let userId = "test-user-no-tokens"
        self.mockAPIClient.mockFetchResults = [ParsePushTokenResponse]()

        // When
        let tokens = try await sut.fetchPushTokens(for: userId)

        // Then
        XCTAssertTrue(self.mockAPIClient.fetchObjectsCalled)
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
