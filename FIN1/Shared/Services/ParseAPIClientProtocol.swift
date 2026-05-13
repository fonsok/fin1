import Foundation

// MARK: - Parse API Client Protocol

/// Protocol for making HTTP requests to Parse Server
protocol ParseAPIClientProtocol: Sendable {
    /// Fetches objects from a Parse class
    func fetchObjects<T: Decodable & Sendable>(
        className: String,
        query: [String: Any]?,
        include: [String]?,
        orderBy: String?,
        limit: Int?
    ) async throws -> [T]

    /// Fetches a single object by ID
    func fetchObject<T: Decodable & Sendable>(
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
    func updateObject<T: Codable & Sendable>(
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
    let accountType: String?
    let companyKybCompleted: Bool?
    let companyKybStep: String?
    let companyKybStatus: String?
    let onboardingCompleted: Bool?
    let onboardingStep: String?
}

/// Payload from `getUserMe` (`backend/.../user/profile.js`): account/KYB plus identity slice (one round-trip).
struct ParseUserMeResponse: Decodable {
    let id: String?
    let email: String?
    let role: String?
    let kycStatus: String?
    let customerNumber: String?
    let accountType: String?
    let companyKybCompleted: Bool?
    let companyKybStep: String?
    let companyKybStatus: String?
    let onboardingCompleted: Bool?
    let onboardingStep: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case role
        case kycStatus
        case customerNumber
        case legacyCustomerNumber = "customerId"
        case accountType
        case companyKybCompleted
        case companyKybStep
        case companyKybStatus
        case onboardingCompleted
        case onboardingStep
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id)
        self.email = try c.decodeIfPresent(String.self, forKey: .email)
        self.role = try c.decodeIfPresent(String.self, forKey: .role)
        self.kycStatus = try c.decodeIfPresent(String.self, forKey: .kycStatus)
        self.accountType = try c.decodeIfPresent(String.self, forKey: .accountType)
        self.companyKybCompleted = try c.decodeIfPresent(Bool.self, forKey: .companyKybCompleted)
        self.companyKybStep = try c.decodeIfPresent(String.self, forKey: .companyKybStep)
        self.companyKybStatus = try c.decodeIfPresent(String.self, forKey: .companyKybStatus)
        self.onboardingCompleted = try c.decodeIfPresent(Bool.self, forKey: .onboardingCompleted)
        self.onboardingStep = try c.decodeIfPresent(String.self, forKey: .onboardingStep)
        if let n = try c.decodeIfPresent(String.self, forKey: .customerNumber), !n.isEmpty {
            self.customerNumber = n
        } else if let legacy = try c.decodeIfPresent(String.self, forKey: .legacyCustomerNumber), !legacy.isEmpty {
            self.customerNumber = legacy
        } else {
            self.customerNumber = nil
        }
    }
}

/// Parse Cloud Functions usually respond with `{ "result": <payload> }`
struct ParseFunctionEnvelope<R: Decodable>: Decodable {
    let result: R
}
