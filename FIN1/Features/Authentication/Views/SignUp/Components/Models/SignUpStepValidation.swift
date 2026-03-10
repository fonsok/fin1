import Foundation

// MARK: - Step Validation Protocol
protocol StepValidation {
    func canProceedToNextStep(for step: SignUpStep, with data: SignUpData) -> Bool
    func getValidationMessage(for step: SignUpStep, with data: SignUpData) -> String?
}

// MARK: - Default Step Validation Implementation
struct DefaultStepValidation: StepValidation {
    private let testModeService: (any TestModeServiceProtocol)?

    init(testModeService: (any TestModeServiceProtocol)? = nil) {
        self.testModeService = testModeService
    }

    var isTestModeEnabled: Bool { testModeService?.isTestModeEnabled ?? false }

    func canProceedToNextStep(for step: SignUpStep, with data: SignUpData) -> Bool {
        switch step {
        case .welcome:
            return true // Account type is always selected (defaults to .individual)

        case .contact:
            return !data.email.isEmpty && !data.username.isEmpty && data.isUsernameValid && !data.password.isEmpty && data.password.count >= 8

        case .accountCreated:
            return true

        case .emailVerification:
            return true

        case .phoneVerification:
            return true

        case .personalInfo:
            return !data.firstName.isEmpty && !data.lastName.isEmpty &&
                   !data.streetAndNumber.isEmpty && !data.postalCode.isEmpty &&
                   !data.city.isEmpty && !data.country.isEmpty

        case .citizenshipTax:
            return !data.nationality.isEmpty && !data.taxNumber.isEmpty

        case .identificationType:
            return true // Identification type is always selected (defaults to .passport)

        case .identificationUploadFront:
            #if targetEnvironment(simulator)
            return true
            #else
            // Allow proceeding if test mode is enabled
            if isTestModeEnabled {
                return true
            }
            return (data.identificationType == .passport && data.passportFrontImage != nil) ||
                   (data.identificationType == .idCard && data.idCardFrontImage != nil)
            #endif

        case .identificationUploadBack:
            #if targetEnvironment(simulator)
            return true
            #else
            // Allow proceeding if test mode is enabled
            if isTestModeEnabled {
                return true
            }
            return (data.identificationType == .passport && data.passportBackImage != nil) ||
                   (data.identificationType == .idCard && data.idCardBackImage != nil)
            #endif

        case .postidentConfirmation:
            return data.identificationConfirmed

        case .identificationConfirm:
            return data.identificationConfirmed

        case .addressConfirm:
            // Allow proceeding if test mode is enabled
            if isTestModeEnabled {
                return true
            }
            return data.addressConfirmed

        case .addressConfirmSuccess:
            return true // Success step, always proceed

        case .financial:
            return true // Employment status and income range have defaults

        case .experience:
            return true // Multi-field step, always proceed

        case .desiredReturn:
            return true // Always proceed (has default value)

        case .nonInsiderDeclaration:
            return data.insiderTradingOptions["None of the above"] == true

        case .moneyLaunderingDeclaration:
            return data.moneyLaunderingDeclaration && data.assetType == .privateAssets

        case .terms:
            return data.acceptedTerms && data.acceptedPrivacyPolicy

        case .summary:
            return true // Always proceed

        case .riskClassificationNote:
            return true // Always proceed

        case .riskClass7Confirmation:
            return true // Always proceed
        }
    }

    func getValidationMessage(for step: SignUpStep, with data: SignUpData) -> String? {
        switch step {
        case .welcome:
            return nil // Account type is always selected (defaults to .individual)

        case .contact:
            if data.email.isEmpty {
                return "Please enter your email address"
            } else if data.username.isEmpty {
                return "Please enter a username"
            } else if !data.isUsernameValid {
                return "Username must be 4-10 characters and contain only letters and numbers"
            } else if data.password.isEmpty {
                return "Please enter your password"
            } else if data.password.count < 8 {
                return "Password must be at least 8 characters"
            }
            return nil

        case .accountCreated:
            return nil

        case .emailVerification:
            return nil

        case .phoneVerification:
            return nil

        case .personalInfo:
            if data.firstName.isEmpty {
                return "Please enter your first name"
            } else if data.lastName.isEmpty {
                return "Please enter your last name"
            } else if data.streetAndNumber.isEmpty {
                return "Please enter your street and number"
            } else if data.postalCode.isEmpty {
                return "Please enter your postal code"
            } else if data.city.isEmpty {
                return "Please enter your city"
            } else if data.country.isEmpty {
                return "Please enter your country"
            }
            return nil

        case .citizenshipTax:
            if data.nationality.isEmpty {
                return "Please enter your nationality"
            } else if data.taxNumber.isEmpty {
                return "Please enter your tax number"
            }
            return nil

        case .identificationType:
            return nil // Identification type is always selected (defaults to .passport)

        case .identificationUploadFront:
            #if targetEnvironment(simulator)
            return nil
            #else
            // Skip validation if test mode is enabled
            if isTestModeEnabled {
                return nil
            }
            if data.identificationType == .passport && data.passportFrontImage == nil {
                return "Please upload the front of your passport"
            } else if data.identificationType == .idCard && data.idCardFrontImage == nil {
                return "Please upload the front of your ID card"
            }
            return nil
            #endif

        case .identificationUploadBack:
            #if targetEnvironment(simulator)
            return nil
            #else
            // Skip validation if test mode is enabled
            if isTestModeEnabled {
                return nil
            }
            if data.identificationType == .passport && data.passportBackImage == nil {
                return "Please upload the back of your passport"
            } else if data.identificationType == .idCard && data.idCardBackImage == nil {
                return "Please upload the back of your ID card"
            }
            return nil
            #endif

        case .postidentConfirmation:
            return !data.identificationConfirmed ? "Please confirm you've started or will start the Postident process" : nil

        case .identificationConfirm:
            return !data.identificationConfirmed ? "Please confirm your identification" : nil

        case .addressConfirm:
            // Skip validation if test mode is enabled
            if isTestModeEnabled {
                return nil
            }
            return !data.addressConfirmed ? "Please confirm your address" : nil

        case .addressConfirmSuccess:
            return nil // Success step, always proceed

        case .financial:
            return nil // Employment status and income range have defaults

        case .experience:
            return nil // Multi-field step, always proceed

        case .desiredReturn:
            return nil // Always proceed (has default value)

        case .nonInsiderDeclaration:
            return data.insiderTradingOptions["None of the above"] != true ? "Please select 'None of the above' to proceed" : nil

        case .moneyLaunderingDeclaration:
            if !data.moneyLaunderingDeclaration {
                return "Please accept the money laundering declaration"
            } else if data.assetType == .businessAssets {
                return "Only Privatvermögen is currently supported"
            }
            return nil

        case .terms:
            if !data.acceptedTerms {
                return "Please accept the Terms of Service"
            } else if !data.acceptedPrivacyPolicy {
                return "Please accept the Privacy Policy"
            }
            return nil

        case .summary:
            return nil // Always proceed

        case .riskClassificationNote:
            return nil // Always proceed

        case .riskClass7Confirmation:
            return nil // Always proceed
        }
    }
}
