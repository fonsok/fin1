import Foundation

// MARK: - Onboarding Progress Model

struct OnboardingProgress: Codable, Sendable {
    let currentStep: String?
    let completedSteps: [String]
    let onboardingCompleted: Bool
    let kycStatus: String?
    let savedData: SavedOnboardingData?
}

// MARK: - Saved Onboarding Data (mirrors `SignUpData.savedOnboardingData()`)

/// All fields are optional because partial saves may omit later steps.
/// Image fields (UIImage) are intentionally excluded — they cannot round-trip through JSON.
struct SavedOnboardingData: Codable, Sendable {
    // Account
    let accountType: String?
    let userRole: String?

    // Contact
    let email: String?
    let phoneNumber: String?
    let username: String?

    // Personal
    let salutation: String?
    let academicTitle: String?
    let firstName: String?
    let lastName: String?
    let streetAndNumber: String?
    let postalCode: String?
    let city: String?
    let state: String?
    let country: String?
    let dateOfBirth: String?
    let placeOfBirth: String?
    let countryOfBirth: String?

    // Citizenship & Tax
    let isNotUSCitizen: Bool?
    let nationality: String?
    let additionalNationalities: String?
    let address: String?
    let taxNumber: String?
    let additionalResidenceCountry: String?

    // Identification
    let identificationType: String?

    // Financial
    let employmentStatus: String?
    let income: String?
    let incomeRange: String?
    let incomeSources: [String: Bool]?
    let otherIncomeSource: String?
    let cashAndLiquidAssets: String?

    // Experience
    let stocksTransactionsCount: String?
    let stocksInvestmentAmount: String?
    let etfsTransactionsCount: String?
    let etfsInvestmentAmount: String?
    let derivativesTransactionsCount: String?
    let derivativesInvestmentAmount: String?
    let derivativesHoldingPeriod: String?
    let otherAssets: [String: Bool]?

    // Risk & Return
    let desiredReturn: String?
    let calculatedRiskClass: Int?
    let finalRiskClass: Int?

    // Declarations
    let insiderTradingOptions: [String: Bool]?
    let moneyLaunderingDeclaration: Bool?
    let assetType: String?
    let leveragedProductsExperience: Bool?
    let financialProductsExperience: Bool?

    // Terms
    let acceptedTerms: Bool?
    let acceptedPrivacyPolicy: Bool?
    let acceptedMarketingConsent: Bool?

    // Meta (prefer `customerNumber`; `customerId` is legacy JSON from older saves)
    let customerNumber: String?
    let customerId: String?

    // Compliance metadata for audit trail (sent with complete/submit; optional for resume)
    let questionnaireVersion: String?
    let termsVersion: String?
    let privacyVersion: String?
}

// MARK: - Onboarding Step Completion Response

struct OnboardingStepResponse: Codable, Sendable {
    let success: Bool
    let nextStep: String?
    let onboardingCompleted: Bool?
}

// MARK: - Email Verification Response

struct SendCodeResponse: Codable, Sendable {
    let success: Bool
    let expiresInSeconds: Int?
}

struct VerifyCodeResponse: Codable, Sendable {
    let success: Bool
    let verified: Bool
}

struct SendPhoneCodeResponse: Codable, Sendable {
    let success: Bool
    let expiresInSeconds: Int?
}

struct VerifyPhoneCodeResponse: Codable, Sendable {
    let success: Bool
    let verified: Bool
}

// MARK: - Onboarding API Service Protocol

@MainActor
protocol OnboardingAPIServiceProtocol {
    /// Fetches the current onboarding progress from the backend
    func getOnboardingProgress() async throws -> OnboardingProgress

    /// Marks a phase-level step as completed on the backend
    func completeStep(step: String, data: SavedOnboardingData?) async throws -> OnboardingStepResponse

    /// Saves partial progress for the current step (for resume capability)
    func savePartialProgress(step: String, data: SavedOnboardingData) async throws

    /// Persists only the current step position (minimal payload).
    func savePartialProgressPositionOnly(step: String) async throws

    /// Sends a 6-digit verification code to the user's email
    func sendVerificationCode() async throws -> SendCodeResponse

    /// Verifies the 6-digit code entered by the user
    func verifyEmailCode(_ code: String) async throws -> VerifyCodeResponse

    /// Sends a 6-digit verification code to the user's phone via SMS
    func sendPhoneVerificationCode(phoneNumber: String) async throws -> SendPhoneCodeResponse

    /// Verifies the 6-digit phone code entered by the user
    func verifyPhoneCode(_ code: String) async throws -> VerifyPhoneCodeResponse
}

// MARK: - Onboarding API Service Implementation

@MainActor
final class OnboardingAPIService: OnboardingAPIServiceProtocol {

    private let apiClient: ParseAPIClientProtocol

    init(apiClient: ParseAPIClientProtocol) {
        self.apiClient = apiClient
    }

    func getOnboardingProgress() async throws -> OnboardingProgress {
        let result: OnboardingProgress = try await apiClient.callFunction(
            "getOnboardingProgress",
            parameters: nil
        )
        return result
    }

    func completeStep(step: String, data: SavedOnboardingData?) async throws -> OnboardingStepResponse {
        var params: [String: Any] = ["step": step]
        if let data = data {
            params["data"] = try data.encodeToJSONDictionary()
        }
        let result: OnboardingStepResponse = try await apiClient.callFunction(
            "completeOnboardingStep",
            parameters: params
        )
        return result
    }

    func savePartialProgress(step: String, data: SavedOnboardingData) async throws {
        let params: [String: Any] = [
            "step": step,
            "data": try data.encodeToJSONDictionary(),
            "partial": true
        ]
        let _: OnboardingStepResponse = try await apiClient.callFunction(
            "saveOnboardingProgress",
            parameters: params
        )
    }

    func savePartialProgressPositionOnly(step: String) async throws {
        let params: [String: Any] = [
            "step": step,
            "data": ["_positionOnly": true],
            "partial": true
        ]
        let _: OnboardingStepResponse = try await apiClient.callFunction(
            "saveOnboardingProgress",
            parameters: params
        )
    }

    func sendVerificationCode() async throws -> SendCodeResponse {
        try await apiClient.callFunction(
            "sendVerificationCode",
            parameters: nil
        )
    }

    func verifyEmailCode(_ code: String) async throws -> VerifyCodeResponse {
        try await apiClient.callFunction(
            "verifyEmailCode",
            parameters: ["code": code]
        )
    }

    func sendPhoneVerificationCode(phoneNumber: String) async throws -> SendPhoneCodeResponse {
        try await apiClient.callFunction(
            "sendPhoneVerificationCode",
            parameters: ["phoneNumber": phoneNumber]
        )
    }

    func verifyPhoneCode(_ code: String) async throws -> VerifyPhoneCodeResponse {
        try await apiClient.callFunction(
            "verifyPhoneCode",
            parameters: ["code": code]
        )
    }
}

// MARK: - SavedOnboardingData → Parse parameters

extension SavedOnboardingData {
    /// Encodes this DTO to a JSON-compatible dictionary for `callFunction` `data` payloads.
    func encodeToJSONDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(self)
        guard let object = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw SavedOnboardingDataEncodingError.invalidJSONObject
        }
        return object
    }
}

private enum SavedOnboardingDataEncodingError: Error {
    case invalidJSONObject
}
