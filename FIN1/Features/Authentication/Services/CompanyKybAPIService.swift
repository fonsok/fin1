import Foundation

// MARK: - Company KYB Progress

struct CompanyKybProgress: Codable, Sendable {
    let currentStep: String?
    let completedSteps: [String]
    let companyKybCompleted: Bool
    let companyKybStatus: String?
    let savedData: SavedCompanyKybData?
}

// MARK: - Saved Company KYB Data

/// Mirrors backend `companyKybStepSchemas` payloads; all optional for partial saves.
struct SavedCompanyKybData: Codable, Sendable {
    // legal_entity
    let legalName: String?
    let legalForm: String?
    let registerType: String?
    let registerNumber: String?
    let registerCourt: String?
    let incorporationCountry: String?
    let notRegisteredReason: String?

    // registered_address
    let streetAndNumber: String?
    let postalCode: String?
    let city: String?
    let country: String?
    let businessStreetAndNumber: String?
    let businessPostalCode: String?
    let businessCity: String?
    let businessCountry: String?

    // tax_compliance
    let vatId: String?
    let nationalTaxNumber: String?
    let economicIdentificationNumber: String?
    let noVatIdDeclared: Bool?

    // beneficial_owners
    let ubos: [SavedCompanyKybUbo]?
    let noUboOver25Percent: Bool?

    // authorized_representatives
    let representatives: [SavedCompanyKybRepresentative]?
    let appAccountHolderIsRepresentative: Bool?

    // documents
    let tradeRegisterExtractReference: String?
    let documentManifest: [SavedCompanyKybDocumentManifestEntry]?
    let documentsAcknowledged: Bool?

    // declarations
    let isPoliticallyExposed: Bool?
    let pepDetails: String?
    let sanctionsSelfDeclarationAccepted: Bool?
    let accuracyDeclarationAccepted: Bool?
    let noTrustThirdPartyDeclarationAccepted: Bool?

    // submission
    let confirmedSummary: Bool?
    let companyFourEyesRequestId: String?

    /// Position-only marker for `saveCompanyKybProgress` (ignored by Codable if absent).
    let _positionOnly: Bool?
}

struct SavedCompanyKybUbo: Codable, Sendable {
    let fullName: String?
    let dateOfBirth: String?
    let nationality: String?
    let ownershipPercent: Double?
    let directOrIndirect: String?
}

struct SavedCompanyKybRepresentative: Codable, Sendable {
    let fullName: String?
    let roleTitle: String?
    let signingAuthority: Bool?
}

struct SavedCompanyKybDocumentManifestEntry: Codable, Sendable {
    let documentType: String?
    let referenceId: String?
}

// MARK: - Responses

struct CompanyKybStepResponse: Codable, Sendable {
    let success: Bool
    let nextStep: String?
    let companyKybCompleted: Bool?
    let companyKybStatus: String?
}

// MARK: - Protocol

protocol CompanyKybAPIServiceProtocol: Sendable {
    func getCompanyKybProgress() async throws -> CompanyKybProgress
    /// `data` is required by the backend for every completed KYB step.
    func completeStep(step: String, data: SavedCompanyKybData) async throws -> CompanyKybStepResponse
    func savePartialProgress(step: String, data: SavedCompanyKybData) async throws
    func savePartialProgressPositionOnly(step: String) async throws
}

// MARK: - Implementation

final class CompanyKybAPIService: CompanyKybAPIServiceProtocol, @unchecked Sendable {

    private let apiClient: ParseAPIClientProtocol

    init(apiClient: ParseAPIClientProtocol) {
        self.apiClient = apiClient
    }

    func getCompanyKybProgress() async throws -> CompanyKybProgress {
        try await apiClient.callFunction(
            "getCompanyKybProgress",
            parameters: nil
        )
    }

    func completeStep(step: String, data: SavedCompanyKybData) async throws -> CompanyKybStepResponse {
        let params: [String: Any] = [
            "step": step,
            "data": try data.encodeToJSONDictionary()
        ]
        return try await apiClient.callFunction(
            "completeCompanyKybStep",
            parameters: params
        )
    }

    func savePartialProgress(step: String, data: SavedCompanyKybData) async throws {
        let params: [String: Any] = [
            "step": step,
            "data": try data.encodeToJSONDictionary(),
            "partial": true
        ]
        let _: CompanyKybStepResponse = try await apiClient.callFunction(
            "saveCompanyKybProgress",
            parameters: params
        )
    }

    func savePartialProgressPositionOnly(step: String) async throws {
        let params: [String: Any] = [
            "step": step,
            "data": ["_positionOnly": true],
            "partial": true
        ]
        let _: CompanyKybStepResponse = try await apiClient.callFunction(
            "saveCompanyKybProgress",
            parameters: params
        )
    }
}

// MARK: - Encoding

extension SavedCompanyKybData {
    func encodeToJSONDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(self)
        guard let object = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw SavedCompanyKybDataEncodingError.invalidJSONObject
        }
        return object
    }
}

private enum SavedCompanyKybDataEncodingError: Error {
    case invalidJSONObject
}
