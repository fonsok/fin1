import Foundation
@testable import FIN1

// MARK: - Mock Parse API Client

/// Mock implementation of ParseAPIClientProtocol for unit testing
final class MockParseAPIClient: ParseAPIClientProtocol {

    // MARK: - Tracking Properties

    var createObjectCalled = false
    var updateObjectCalled = false
    var fetchObjectsCalled = false
    var fetchObjectCalled = false
    var deleteObjectCalled = false
    var callFunctionCalled = false

    var lastClassName: String?
    var lastObjectId: String?
    var lastQuery: [String: Any]?

    // MARK: - Mock Data

    var mockObjectId = "mock-object-id-123"
    var mockCreatedAt = "2026-02-04T10:00:00.000Z"
    var mockUpdatedAt = "2026-02-04T10:00:00.000Z"

    var mockFetchResults: Any?
    var mockFetchSingleResult: Any?
    var mockFunctionResult: Any?

    var shouldThrowError = false
    var errorToThrow: Error = NetworkError.invalidResponse

    // MARK: - ParseAPIClientProtocol Implementation

    func fetchObjects<T: Decodable>(
        className: String,
        query: [String: Any]?,
        include: [String]?,
        orderBy: String?,
        limit: Int?
    ) async throws -> [T] {
        fetchObjectsCalled = true
        lastClassName = className
        lastQuery = query

        if shouldThrowError {
            throw errorToThrow
        }

        if let results = mockFetchResults as? [T] {
            return results
        }

        return []
    }

    func fetchObject<T: Decodable>(
        className: String,
        objectId: String,
        include: [String]?
    ) async throws -> T {
        fetchObjectCalled = true
        lastClassName = className
        lastObjectId = objectId

        if shouldThrowError {
            throw errorToThrow
        }

        guard let result = mockFetchSingleResult as? T else {
            throw NetworkError.invalidResponse
        }

        return result
    }

    func createObject<T: Encodable>(
        className: String,
        object: T
    ) async throws -> ParseResponse {
        createObjectCalled = true
        lastClassName = className

        if shouldThrowError {
            throw errorToThrow
        }

        return ParseResponse(
            objectId: mockObjectId,
            createdAt: mockCreatedAt,
            updatedAt: mockUpdatedAt
        )
    }

    func updateObject<T: Encodable>(
        className: String,
        objectId: String,
        object: T
    ) async throws -> ParseResponse {
        updateObjectCalled = true
        lastClassName = className
        lastObjectId = objectId

        if shouldThrowError {
            throw errorToThrow
        }

        return ParseResponse(
            objectId: objectId,
            createdAt: mockCreatedAt,
            updatedAt: mockUpdatedAt
        )
    }

    func deleteObject(
        className: String,
        objectId: String
    ) async throws {
        deleteObjectCalled = true
        lastClassName = className
        lastObjectId = objectId

        if shouldThrowError {
            throw errorToThrow
        }
    }

    func callFunction<T: Decodable>(
        _ name: String,
        parameters: [String: Any]?
    ) async throws -> T {
        callFunctionCalled = true

        if shouldThrowError {
            throw errorToThrow
        }

        guard let result = mockFunctionResult as? T else {
            throw NetworkError.invalidResponse
        }

        return result
    }

    func login(username: String, password: String) async throws -> ParseLoginResponse {
        if shouldThrowError { throw errorToThrow }
        return ParseLoginResponse(
            objectId: "mock-id",
            sessionToken: "r:mock-token",
            username: username,
            email: username,
            role: "investor",
            stableId: "user:\(username)",
            firstName: "Mock",
            lastName: "User"
        )
    }

    func resetCircuitBreaker() async {}

    // MARK: - Helper Methods

    func reset() {
        createObjectCalled = false
        updateObjectCalled = false
        fetchObjectsCalled = false
        fetchObjectCalled = false
        deleteObjectCalled = false
        callFunctionCalled = false
        lastClassName = nil
        lastObjectId = nil
        lastQuery = nil
        shouldThrowError = false
    }
}
