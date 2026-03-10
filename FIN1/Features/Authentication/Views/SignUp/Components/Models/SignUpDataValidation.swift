import Foundation

// MARK: - SignUp Data Validation Extensions

extension SignUpData {
    // MARK: - Username Validation
    var isUsernameValid: Bool {
        let usernameRegex = "^[A-Za-z0-9]{4,10}$"
        return username.range(of: usernameRegex, options: .regularExpression) != nil
    }

    // MARK: - Password Validation
    var isPasswordValid: Bool {
        password.count >= 8 &&
        password.range(of: "[A-Z]", options: .regularExpression) != nil &&
        password.range(of: "[a-z]", options: .regularExpression) != nil &&
        password.range(of: "[0-9]", options: .regularExpression) != nil &&
        password.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil
    }

    var isPasswordConfirmed: Bool {
        password == confirmPassword
    }

    // MARK: - Email Validation
    var isEmailValid: Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    // MARK: - Phone Number Validation
    var isPhoneNumberValid: Bool {
        let phoneRegex = "^\\+[1-9]\\d{1,14}$"
        return phoneNumber.range(of: phoneRegex, options: .regularExpression) != nil
    }

    // MARK: - Personal Information Validation
    var isPersonalInfoValid: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !streetAndNumber.isEmpty &&
        !postalCode.isEmpty &&
        !city.isEmpty &&
        !state.isEmpty &&
        !country.isEmpty
    }

    // MARK: - Tax Information Validation
    var isTaxInfoValid: Bool {
        !taxNumber.isEmpty &&
        !nationality.isEmpty
    }

    // MARK: - Identification Validation
    var isIdentificationValid: Bool {
        switch identificationType {
        case .passport:
            return passportFrontImage != nil && passportBackImage != nil
        case .idCard:
            return idCardFrontImage != nil && idCardBackImage != nil
        case .postident:
            return true // Postident doesn't require image upload
        }
    }

    // MARK: - Financial Information Validation
    var isFinancialInfoValid: Bool {
        !income.isEmpty &&
        !incomeSources.isEmpty &&
        incomeSources.values.contains(true) // At least one income source selected
    }

    // MARK: - Investment Experience Validation
    var isInvestmentExperienceValid: Bool {
        // At least one type of investment experience should be provided
        return stocksTransactionsCount != .none ||
               etfsTransactionsCount != .none ||
               derivativesTransactionsCount != .none ||
               otherAssets.values.contains(true)
    }

    // MARK: - Legal Declarations Validation
    var areLegalDeclarationsValid: Bool {
        acceptedTerms &&
        acceptedPrivacyPolicy &&
        moneyLaunderingDeclaration &&
        insiderTradingOptions.values.contains(true) // At least one option selected
    }

    // MARK: - Overall Form Validation
    var isFormValid: Bool {
        isEmailValid &&
        isUsernameValid &&
        isPasswordValid &&
        isPasswordConfirmed &&
        isPhoneNumberValid &&
        isPersonalInfoValid &&
        isTaxInfoValid &&
        isFinancialInfoValid &&
        isInvestmentExperienceValid &&
        areLegalDeclarationsValid
    }

    // MARK: - Step-Specific Validation
    func isValidForStep(_ step: SignUpStep) -> Bool {
        switch step {
        case .welcome:
            return true // Always valid
        case .contact:
            return isEmailValid && isUsernameValid && isPasswordValid && isPasswordConfirmed && isPhoneNumberValid
        case .accountCreated:
            return true
        case .emailVerification:
            return true
        case .phoneVerification:
            return true
        case .personalInfo:
            return isPersonalInfoValid
        case .citizenshipTax:
            return isTaxInfoValid
        case .identificationType:
            return true // Selection step
        case .identificationUploadFront, .identificationUploadBack:
            return isIdentificationValid
        case .postidentConfirmation:
            return true // Postident process
        case .identificationConfirm:
            return identificationConfirmed
        case .addressConfirm:
            return addressConfirmed
        case .addressConfirmSuccess:
            return true // Success step
        case .financial:
            return isFinancialInfoValid
        case .experience:
            return isInvestmentExperienceValid
        case .desiredReturn:
            return true // Selection step
        case .nonInsiderDeclaration:
            return insiderTradingOptions.values.contains(true)
        case .moneyLaunderingDeclaration:
            return moneyLaunderingDeclaration
        case .terms:
            return acceptedTerms && acceptedPrivacyPolicy
        case .summary:
            return isFormValid
        case .riskClassificationNote:
            return true // Information step
        case .riskClass7Confirmation:
            return userSelectedRiskClass != nil
        }
    }
}
