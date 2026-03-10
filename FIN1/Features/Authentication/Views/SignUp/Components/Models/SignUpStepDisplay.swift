import SwiftUI

// MARK: - SignUp Step Display Properties

extension SignUpStep {
    /// Human-readable title for each step
    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .contact: return "Contact Information"
        case .accountCreated: return "Account Created"
        case .emailVerification: return "Email Verification"
        case .phoneVerification: return "Phone Verification"
        case .personalInfo: return "Personal Information"
        case .citizenshipTax: return "Citizenship & Tax"
        case .identificationType: return "Identification Type"
        case .identificationUploadFront: return "Upload ID Front"
        case .identificationUploadBack: return "Upload ID Back"
        case .postidentConfirmation: return "Postident"
        case .identificationConfirm: return "ID Confirmation"
        case .addressConfirm: return "Address Confirmation"
        case .addressConfirmSuccess: return "Address Success"
        case .financial: return "Financial Information"
        case .experience: return "Investment Experience"
        case .desiredReturn: return "Desired Return"
        case .nonInsiderDeclaration: return "Non-Insider Declaration"
        case .moneyLaunderingDeclaration: return "Money Laundering Declaration"
        case .terms: return "Terms & Conditions"
        case .summary: return "Summary"
        case .riskClassificationNote: return "Note on risk classification"
        case .riskClass7Confirmation: return "Risk Class 7 Confirmation"
        }
    }

    /// Description for each step
    var description: String {
        switch self {
        case .welcome: return "Choose your account type"
        case .contact: return "Enter your contact details"
        case .accountCreated: return "Account successfully created"
        case .emailVerification: return "Verify your email address"
        case .phoneVerification: return "Verify your phone number"
        case .personalInfo: return "Provide personal information"
        case .citizenshipTax: return "Citizenship and tax details"
        case .identificationType: return "Select ID document type"
        case .identificationUploadFront: return "Upload front of ID"
        case .identificationUploadBack: return "Upload back of ID"
        case .postidentConfirmation: return "Postident verification"
        case .identificationConfirm: return "Confirm ID documents"
        case .addressConfirm: return "Confirm your address"
        case .addressConfirmSuccess: return "Address confirmed"
        case .financial: return "Financial background"
        case .experience: return "Investment experience"
        case .desiredReturn: return "Return expectations"
        case .nonInsiderDeclaration: return "Legal declarations"
        case .moneyLaunderingDeclaration: return "AML compliance"
        case .terms: return "Terms and conditions"
        case .summary: return "Review all information"
        case .riskClassificationNote: return "Risk classification information"
        case .riskClass7Confirmation: return "Confirm high-risk selection"
        }
    }

    /// Icon for each step
    var icon: String {
        switch self {
        case .welcome: return "person.badge.plus"
        case .contact: return "envelope"
        case .accountCreated: return "checkmark.circle"
        case .emailVerification: return "envelope.badge.shield.half.filled"
        case .phoneVerification: return "phone.badge.checkmark"
        case .personalInfo: return "person.text.rectangle"
        case .citizenshipTax: return "flag"
        case .identificationType: return "doc.text"
        case .identificationUploadFront: return "camera"
        case .identificationUploadBack: return "camera.fill"
        case .postidentConfirmation: return "building.columns"
        case .identificationConfirm: return "checkmark.shield"
        case .addressConfirm: return "house"
        case .addressConfirmSuccess: return "checkmark.house"
        case .financial: return "chart.bar"
        case .experience: return "chart.line.uptrend.xyaxis"
        case .desiredReturn: return "percent"
        case .nonInsiderDeclaration: return "hand.raised"
        case .moneyLaunderingDeclaration: return "shield"
        case .terms: return "doc.text"
        case .summary: return "list.bullet"
        case .riskClassificationNote: return "exclamationmark.triangle"
        case .riskClass7Confirmation: return "exclamationmark.triangle.fill"
        }
    }

    /// Whether this step is required for completion
    var isRequired: Bool {
        switch self {
        case .accountCreated, .addressConfirmSuccess:
            return false
        default:
            return true
        }
    }

    /// Whether this step can be skipped
    var canSkip: Bool {
        switch self {
        case .accountCreated, .addressConfirmSuccess:
            return true
        default:
            return false
        }
    }

    /// The onboarding phase this step belongs to
    var phase: OnboardingPhase {
        switch self {
        case .welcome, .contact, .accountCreated, .emailVerification, .phoneVerification:
            return .quickStart
        case .personalInfo, .citizenshipTax, .identificationType,
             .identificationUploadFront, .identificationUploadBack,
             .postidentConfirmation, .identificationConfirm,
             .addressConfirm, .addressConfirmSuccess:
            return .kyc
        case .financial, .experience, .desiredReturn,
             .nonInsiderDeclaration, .riskClassificationNote,
             .riskClass7Confirmation:
            return .investmentReadiness
        case .moneyLaunderingDeclaration, .terms, .summary:
            return .legalConsent
        }
    }
}
