import SwiftUI

// MARK: - SignUp Step Enum

/// Enum representing all SignUp steps with automatic numbering
enum SignUpStep: Int, CaseIterable, Identifiable {
    case welcome = 1
    case contact = 2
    case accountCreated = 3
    case personalInfo = 4
    case citizenshipTax = 5
    case identificationType = 6
    case identificationUploadFront = 7
    case identificationUploadBack = 8
    case postidentConfirmation = 9
    case identificationConfirm = 10
    case addressConfirm = 11
    case addressConfirmSuccess = 12
    case financial = 13
    case experience = 14
    case desiredReturn = 15
    case nonInsiderDeclaration = 16
    case moneyLaunderingDeclaration = 17
    case terms = 18
    case summary = 19
    case riskClassificationNote = 20
    case riskClass7Confirmation = 21

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
}
