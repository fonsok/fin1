@testable import FIN1
import Foundation

// MARK: - Mock Parse API Client

/// Mock implementation of ParseAPIClientProtocol for unit testing
final class MockParseAPIClient: ParseAPIClientProtocol, @unchecked Sendable {

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
    var lastFunctionName: String?
    var lastFunctionParameters: [String: Any]?

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
        self.fetchObjectsCalled = true
        self.lastClassName = className
        self.lastQuery = query

        if self.shouldThrowError {
            throw self.errorToThrow
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
        self.fetchObjectCalled = true
        self.lastClassName = className
        self.lastObjectId = objectId

        if self.shouldThrowError {
            throw self.errorToThrow
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
        self.createObjectCalled = true
        self.lastClassName = className

        if self.shouldThrowError {
            throw self.errorToThrow
        }

        return ParseResponse(
            objectId: self.mockObjectId,
            createdAt: self.mockCreatedAt,
            updatedAt: self.mockUpdatedAt
        )
    }

    func updateObject<T: Encodable>(
        className: String,
        objectId: String,
        object: T
    ) async throws -> ParseResponse {
        self.updateObjectCalled = true
        self.lastClassName = className
        self.lastObjectId = objectId

        if self.shouldThrowError {
            throw self.errorToThrow
        }

        return ParseResponse(
            objectId: objectId,
            createdAt: self.mockCreatedAt,
            updatedAt: self.mockUpdatedAt
        )
    }

    func deleteObject(
        className: String,
        objectId: String
    ) async throws {
        self.deleteObjectCalled = true
        self.lastClassName = className
        self.lastObjectId = objectId

        if self.shouldThrowError {
            throw self.errorToThrow
        }
    }

    func callFunction<T: Decodable>(
        _ name: String,
        parameters: [String: Any]?
    ) async throws -> T {
        self.callFunctionCalled = true
        self.lastFunctionName = name
        self.lastFunctionParameters = parameters

        if self.shouldThrowError {
            throw self.errorToThrow
        }

        // Tests that do not explicitly set mockFunctionResult can still succeed for
        // the pool-participation cloud-function contract by synthesizing a response.
        if self.mockFunctionResult == nil,
           (name == "recordPoolTradeParticipation" || name == "updatePoolTradeParticipation"),
           let params = parameters,
           let synthesized: T = decodeFromJSONDictionary([
               "objectId": (name == "updatePoolTradeParticipation"
                   ? (params["participationId"] as? String ?? mockObjectId)
                   : mockObjectId),
               "tradeId": params["tradeId"] as? String ?? "",
               "investmentId": params["investmentId"] as? String ?? "",
               "poolReservationId": (params["poolReservationId"] as? String) as Any,
               "poolNumber": (params["poolNumber"] as? Int) as Any,
               "allocatedAmount": (params["allocatedAmount"] as? Double) as Any,
               "totalTradeValue": (params["totalTradeValue"] as? Double) as Any,
               "ownershipPercentage": (params["ownershipPercentage"] as? Double) as Any,
               "profitShare": (params["profitShare"] as? Double) as Any,
               "createdAt": ["iso": mockCreatedAt],
               "updatedAt": ["iso": mockUpdatedAt]
           ]) {
            return synthesized
        }

        guard let result = mockFunctionResult as? T else {
            throw NetworkError.invalidResponse
        }

        return result
    }

    func login(username: String, password: String) async throws -> ParseLoginResponse {
        if self.shouldThrowError { throw self.errorToThrow }
        return ParseLoginResponse(
            objectId: "mock-id",
            sessionToken: "r:mock-token",
            username: username,
            email: username,
            role: "investor",
            stableId: "user:\(username)",
            firstName: "Mock",
            lastName: "User",
            accountType: nil,
            companyKybCompleted: nil,
            companyKybStep: nil,
            companyKybStatus: nil,
            onboardingCompleted: nil,
            onboardingStep: nil
        )
    }

    func resetCircuitBreaker() async {}

    // MARK: - Helper Methods

    func reset() {
        self.createObjectCalled = false
        self.updateObjectCalled = false
        self.fetchObjectsCalled = false
        self.fetchObjectCalled = false
        self.deleteObjectCalled = false
        self.callFunctionCalled = false
        self.lastClassName = nil
        self.lastObjectId = nil
        self.lastQuery = nil
        self.lastFunctionName = nil
        self.lastFunctionParameters = nil
        self.shouldThrowError = false
    }

    private func decodeFromJSONDictionary<T: Decodable>(_ dictionary: [String: Any]) -> T? {
        guard JSONSerialization.isValidJSONObject(dictionary),
              let data = try? JSONSerialization.data(withJSONObject: dictionary) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(T.self, from: data)
    }
}
