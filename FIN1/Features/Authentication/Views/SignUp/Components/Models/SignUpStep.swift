import SwiftUI

// MARK: - Onboarding Phase

/// Groups SignUp steps into user-facing phases for progressive disclosure.
/// Instead of "Step 7 of 21", the progress bar can show "Phase 2 – KYC".
enum OnboardingPhase: Int, CaseIterable, Identifiable, Sendable {
    case quickStart = 1
    case kyc = 2
    case investmentReadiness = 3
    case legalConsent = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .quickStart: return "Account Setup"
        case .kyc: return "Identity Verification"
        case .investmentReadiness: return "Investment Profile"
        case .legalConsent: return "Legal & Consent"
        }
    }

    var estimatedMinutes: Int {
        switch self {
        case .quickStart: return 2
        case .kyc: return 5
        case .investmentReadiness: return 3
        case .legalConsent: return 1
        }
    }

    /// Backend step names for `completeOnboardingStep` cloud function
    var backendStepNames: [String] {
        switch self {
        case .quickStart: return ["personal", "emailVerification", "phoneVerification"]
        case .kyc: return ["address", "tax", "verification"]
        case .investmentReadiness: return ["experience", "risk"]
        case .legalConsent: return ["consents"]
        }
    }

    /// The backend step name that represents this phase being fully completed
    var completionBackendStep: String {
        switch self {
        case .quickStart: return "personal"
        case .kyc: return "verification"
        case .investmentReadiness: return "risk"
        case .legalConsent: return "consents"
        }
    }
}

// MARK: - SignUp Step Enum

/// Enum representing all SignUp steps with automatic numbering
enum SignUpStep: Int, CaseIterable, Identifiable {
    case welcome = 1
    case contact = 2
    case accountCreated = 3
    case emailVerification = 4
    case phoneVerification = 5
    case personalInfo = 6
    case citizenshipTax = 7
    case identificationType = 8
    case identificationUploadFront = 9
    case identificationUploadBack = 10
    case postidentConfirmation = 11
    case identificationConfirm = 12
    case addressConfirm = 13
    case addressConfirmSuccess = 14
    case financial = 15
    case experience = 16
    case desiredReturn = 17
    case nonInsiderDeclaration = 18
    case moneyLaunderingDeclaration = 19
    case terms = 20
    case summary = 21
    case riskClassificationNote = 22
    case riskClass7Confirmation = 23

    var id: Int { rawValue }

    /// Get all steps for a specific user role
    static func stepsForRole(_ role: UserRole) -> [SignUpStep] {
        switch role {
        case .trader:
            // Traders see all steps including insider declaration
            return SignUpStep.allCases
        case .investor, .other, .admin, .customerService:
            // Investors and staff roles skip the insider declaration step
            return SignUpStep.allCases.filter { $0 != .nonInsiderDeclaration }
        }
    }

    /// Get the step number for a specific role (accounting for skipped steps)
    func stepNumberForRole(_ role: UserRole) -> Int {
        let stepsForRole = SignUpStep.stepsForRole(role)
        guard let index = stepsForRole.firstIndex(of: self) else {
            return 0 // Step not available for this role
        }
        return index + 1 // Return 1-based step number
    }

    /// Get total steps for a specific role
    static func totalStepsForRole(_ role: UserRole) -> Int {
        return stepsForRole(role).count
    }

    /// Stable string key for backend persistence (mirrors enum case name)
    var backendKey: String {
        String(describing: self)
    }

    /// Reverse-map a backend key back to a SignUpStep
    static func fromBackendKey(_ key: String) -> SignUpStep? {
        allCases.first { String(describing: $0) == key }
    }
}
