import Foundation

// MARK: - Parse API Client Protocol

/// Protocol for making HTTP requests to Parse Server
protocol ParseAPIClientProtocol {
    /// Fetches objects from a Parse class
    func fetchObjects<T: Decodable>(
        className: String,
        query: [String: Any]?,
        include: [String]?,
        orderBy: String?,
        limit: Int?
    ) async throws -> [T]

    /// Fetches a single object by ID
    func fetchObject<T: Decodable>(
        className: String,
        objectId: String,
        include: [String]?
    ) async throws -> T

    /// Creates a new object in Parse
    func createObject<T: Encodable>(
        className: String,
        object: T
    ) async throws -> ParseResponse

    /// Updates an existing object in Parse
    func updateObject<T: Codable>(
        className: String,
        objectId: String,
        object: T
    ) async throws -> ParseResponse

    /// Deletes an object from Parse
    func deleteObject(
        className: String,
        objectId: String
    ) async throws

    /// Calls a Parse Cloud Function
    /// - Note: Uses REST endpoint: POST /functions/{name}
    func callFunction<T: Decodable>(
        _ name: String,
        parameters: [String: Any]?
    ) async throws -> T

    /// Logs in a user via Parse REST API and returns session data
    func login(username: String, password: String) async throws -> ParseLoginResponse

    /// Resets the circuit breaker to allow requests again (used after health check recovery)
    func resetCircuitBreaker() async
}

// MARK: - Parse Response Models

struct ParseResponse: Codable {
    let objectId: String
    let createdAt: String?
    let updatedAt: String?

    /// Custom decoding: Parse returns objectId only on CREATE, not on UPDATE.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.objectId = (try? container.decode(String.self, forKey: .objectId)) ?? ""
        self.createdAt = try? container.decode(String.self, forKey: .createdAt)
        self.updatedAt = try? container.decode(String.self, forKey: .updatedAt)
    }

    init(objectId: String, createdAt: String? = nil, updatedAt: String? = nil) {
        self.objectId = objectId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ParseQueryResponse<T: Decodable>: Decodable {
    let results: [T]
}

struct ParseLoginResponse: Decodable {
    let objectId: String
    let sessionToken: String
    let username: String?
    let email: String?
    let role: String?
    let stableId: String?
    let firstName: String?
    let lastName: String?
}

/// Parse Cloud Functions usually respond with `{ "result": <payload> }`
struct ParseFunctionEnvelope<R: Decodable>: Decodable {
    let result: R
}
