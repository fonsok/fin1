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

    /// Registers a new user via Parse REST API (`POST /users`) and returns session data
    func signUp(user: User) async throws -> ParseLoginResponse

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
    let riskTolerance: Int?
    let acceptedTerms: Bool?
    let acceptedPrivacyPolicy: Bool?
    let acceptedTermsVersion: String?
    let acceptedPrivacyPolicyVersion: String?
    let acceptedTermsDate: String?
    let acceptedPrivacyPolicyDate: String?
    let acceptedTraderAgreement: Bool?
    let acceptedTraderAgreementVersion: String?
    let acceptedTraderAgreementDate: String?
    let acceptedInvestorAgreement: Bool?
    let acceptedInvestorAgreementVersion: String?
    let acceptedInvestorAgreementDate: String?
    let roleAgreementAccepted: Bool?

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
        case riskTolerance
        case acceptedTerms
        case acceptedPrivacyPolicy
        case acceptedTermsVersion
        case acceptedPrivacyPolicyVersion
        case acceptedTermsDate
        case acceptedPrivacyPolicyDate
        case acceptedTraderAgreement
        case acceptedTraderAgreementVersion
        case acceptedTraderAgreementDate
        case acceptedInvestorAgreement
        case acceptedInvestorAgreementVersion
        case acceptedInvestorAgreementDate
        case roleAgreementAccepted
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
        self.riskTolerance = try c.decodeIfPresent(Int.self, forKey: .riskTolerance)
        self.acceptedTerms = try c.decodeIfPresent(Bool.self, forKey: .acceptedTerms)
        self.acceptedPrivacyPolicy = try c.decodeIfPresent(Bool.self, forKey: .acceptedPrivacyPolicy)
        self.acceptedTermsVersion = try c.decodeIfPresent(String.self, forKey: .acceptedTermsVersion)
        self.acceptedPrivacyPolicyVersion = try c.decodeIfPresent(String.self, forKey: .acceptedPrivacyPolicyVersion)
        self.acceptedTermsDate = try c.decodeIfPresent(String.self, forKey: .acceptedTermsDate)
        self.acceptedPrivacyPolicyDate = try c.decodeIfPresent(String.self, forKey: .acceptedPrivacyPolicyDate)
        self.acceptedTraderAgreement = try c.decodeIfPresent(Bool.self, forKey: .acceptedTraderAgreement)
        self.acceptedTraderAgreementVersion = try c.decodeIfPresent(String.self, forKey: .acceptedTraderAgreementVersion)
        self.acceptedTraderAgreementDate = try c.decodeIfPresent(String.self, forKey: .acceptedTraderAgreementDate)
        self.acceptedInvestorAgreement = try c.decodeIfPresent(Bool.self, forKey: .acceptedInvestorAgreement)
        self.acceptedInvestorAgreementVersion = try c.decodeIfPresent(String.self, forKey: .acceptedInvestorAgreementVersion)
        self.acceptedInvestorAgreementDate = try c.decodeIfPresent(String.self, forKey: .acceptedInvestorAgreementDate)
        self.roleAgreementAccepted = try c.decodeIfPresent(Bool.self, forKey: .roleAgreementAccepted)
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
