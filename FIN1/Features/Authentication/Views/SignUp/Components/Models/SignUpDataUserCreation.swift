import Foundation

// MARK: - SignUp Data User Creation Extensions

extension SignUpData {
    // MARK: - User Creation
    func createUser() throws -> User {
        // Validate required fields
        guard !email.isEmpty else {
            throw UserCreationError.missingEmail
        }

        guard !firstName.isEmpty else {
            throw UserCreationError.missingFirstName
        }

        guard !lastName.isEmpty else {
            throw UserCreationError.missingLastName
        }

        guard !password.isEmpty else {
            throw UserCreationError.missingPassword
        }

        // dateOfBirth is always set to a default value, so no need to check for nil

        guard acceptedTerms else {
            throw UserCreationError.termsNotAccepted
        }

        guard acceptedPrivacyPolicy else {
            throw UserCreationError.privacyPolicyNotAccepted
        }

        return User(
            id: UUID().uuidString,
            customerId: customerId,
            accountType: accountType,
            email: email,
            username: username,
            phoneNumber: phoneNumber,
            password: password,
            salutation: salutation,
            academicTitle: academicTitle,
            firstName: firstName,
            lastName: lastName,
            streetAndNumber: streetAndNumber,
            postalCode: postalCode,
            city: city,
            state: state,
            country: country,
            dateOfBirth: dateOfBirth,
            placeOfBirth: placeOfBirth,
            countryOfBirth: countryOfBirth,
            role: userRole,
            employmentStatus: employmentStatus,
            income: Double(income) ?? 0,
            incomeRange: incomeRange,
            riskTolerance: finalRiskClass.rawValue,
            address: address,
            nationality: nationality,
            additionalNationalities: additionalNationalities,
            taxNumber: taxNumber,
            additionalTaxResidences: additionalResidenceCountry,
            isNotUSCitizen: isNotUSCitizen,
            identificationType: identificationType,
            passportFrontImageURL: nil, // TODO: Handle image upload
            passportBackImageURL: nil,
            idCardFrontImageURL: nil,
            idCardBackImageURL: nil,
            identificationConfirmed: identificationConfirmed,
            addressConfirmed: addressConfirmed,
            addressVerificationDocumentURL: nil, // TODO: Handle image upload
            leveragedProductsExperience: leveragedProductsExperience,
            financialProductsExperience: financialProductsExperience,
            investmentExperience: getInvestmentExperienceLevel(),
            tradingFrequency: getTradingFrequency(),
            investmentKnowledge: getInvestmentKnowledge(),
            desiredReturn: desiredReturn,
            insiderTradingOptions: insiderTradingOptions,
            moneyLaunderingDeclaration: moneyLaunderingDeclaration,
            assetType: assetType,
            profileImageURL: nil,
            isEmailVerified: false,
            isKYCCompleted: false,
            acceptedTerms: acceptedTerms,
            acceptedPrivacyPolicy: acceptedPrivacyPolicy,
            acceptedMarketingConsent: acceptedMarketingConsent,
            lastLoginDate: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - Experience Level Calculations (using services)
    private func getInvestmentExperienceLevel() -> Int {
        if let service = investmentExperienceCalculationService {
            return service.calculateInvestmentExperienceLevel(for: self)
        }
        // Fallback to legacy implementation
        return calculateInvestmentExperienceLevelLegacy()
    }

    private func getTradingFrequency() -> Int {
        if let service = investmentExperienceCalculationService {
            return service.calculateTradingFrequency(for: self)
        }
        // Fallback to legacy implementation
        return calculateTradingFrequencyLegacy()
    }

    private func getInvestmentKnowledge() -> Int {
        if let service = investmentExperienceCalculationService {
            return service.calculateInvestmentKnowledge(for: self)
        }
        // Fallback to legacy implementation
        return calculateInvestmentKnowledgeLegacy()
    }

    // MARK: - Legacy Experience Level Calculations (kept for backward compatibility)
    private func calculateInvestmentExperienceLevelLegacy() -> Int {
        var experience = 0

        // Stocks experience
        switch stocksTransactionsCount {
        case .none: experience += 0
        case .oneToTen: experience += 1
        case .tenToFifty: experience += 2
        case .fiftyPlus: experience += 3
        }

        // ETFs experience
        switch etfsTransactionsCount {
        case .none: experience += 0
        case .oneToTen: experience += 1
        case .tenToTwenty: experience += 2
        case .moreThanTwenty: experience += 3
        }

        // Derivatives experience
        switch derivativesTransactionsCount {
        case .none: experience += 0
        case .oneToTen: experience += 1
        case .tenToFifty: experience += 2
        case .fiftyPlus: experience += 3
        }

        // Cap at 10 for the scale
        return min(experience, 10)
    }

    private func calculateTradingFrequencyLegacy() -> Int {
        // For traders, base on derivatives experience
        if userRole == .trader {
            switch derivativesTransactionsCount {
            case .none: return 0
            case .oneToTen: return 2
            case .tenToFifty: return 5
            case .fiftyPlus: return 8
            }
        }

        // For investors, base on overall experience
        let experience = calculateInvestmentExperienceLevelLegacy()
        return min(experience / 2, 5) // Scale down for investors
    }

    private func calculateInvestmentKnowledgeLegacy() -> Int {
        var knowledge = 0

        // Base knowledge from experience
        knowledge += calculateInvestmentExperienceLevelLegacy()

        // Additional knowledge from investment amounts
        if stocksInvestmentAmount != .hundredToTenThousand { knowledge += 1 }
        if etfsInvestmentAmount != .hundredToTenThousand { knowledge += 1 }
        if derivativesInvestmentAmount != .zeroToThousand { knowledge += 2 }

        // Knowledge from other assets
        if otherAssets["Real estate"] == true { knowledge += 1 }
        if otherAssets["Gold, silver"] == true { knowledge += 1 }

        // Cap at 10 for the scale
        return min(knowledge, 10)
    }

    // MARK: - Data Export for API
    func exportSignUpData() -> [String: Any] {
        return [
            "accountType": accountType.rawValue,
            "userRole": userRole.rawValue,
            "email": email,
            "phoneNumber": phoneNumber,
            "username": username,
            "salutation": salutation.rawValue,
            "academicTitle": academicTitle,
            "firstName": firstName,
            "lastName": lastName,
            "streetAndNumber": streetAndNumber,
            "postalCode": postalCode,
            "city": city,
            "state": state,
            "country": country,
            "dateOfBirth": ISO8601DateFormatter().string(from: dateOfBirth),
            "placeOfBirth": placeOfBirth,
            "countryOfBirth": countryOfBirth,
            "isNotUSCitizen": isNotUSCitizen,
            "nationality": nationality,
            "additionalNationalities": additionalNationalities,
            "address": address,
            "taxNumber": taxNumber,
            "additionalResidenceCountry": additionalResidenceCountry,
            "identificationType": identificationType.rawValue,
            "employmentStatus": employmentStatus.rawValue,
            "income": income,
            "incomeRange": incomeRange.rawValue,
            "incomeSources": incomeSources,
            "otherIncomeSource": otherIncomeSource,
            "cashAndLiquidAssets": cashAndLiquidAssets.rawValue,
            "stocksTransactionsCount": stocksTransactionsCount.rawValue,
            "stocksInvestmentAmount": stocksInvestmentAmount.rawValue,
            "etfsTransactionsCount": etfsTransactionsCount.rawValue,
            "etfsInvestmentAmount": etfsInvestmentAmount.rawValue,
            "derivativesTransactionsCount": derivativesTransactionsCount.rawValue,
            "derivativesInvestmentAmount": derivativesInvestmentAmount.rawValue,
            "derivativesHoldingPeriod": derivativesHoldingPeriod.rawValue,
            "otherAssets": otherAssets,
            "desiredReturn": desiredReturn.rawValue,
            "insiderTradingOptions": insiderTradingOptions,
            "moneyLaunderingDeclaration": moneyLaunderingDeclaration,
            "assetType": assetType.rawValue,
            "leveragedProductsExperience": leveragedProductsExperience,
            "financialProductsExperience": financialProductsExperience,
            "acceptedTerms": acceptedTerms,
            "acceptedPrivacyPolicy": acceptedPrivacyPolicy,
            "acceptedMarketingConsent": acceptedMarketingConsent,
            "calculatedRiskClass": calculatedRiskClass.rawValue,
            "finalRiskClass": finalRiskClass.rawValue,
            "customerId": customerId
        ]
    }

    // MARK: - Data Validation for API Submission
    func validateForSubmission() -> (isValid: Bool, errors: [String]) {
        var errors: [String] = []

        if !isEmailValid { errors.append("Invalid email format") }
        if !isUsernameValid { errors.append("Username must be 4-10 alphanumeric characters") }
        if !isPasswordValid { errors.append("Password must contain uppercase, lowercase, number, and special character") }
        if !isPasswordConfirmed { errors.append("Passwords do not match") }
        if !isPhoneNumberValid { errors.append("Invalid phone number format") }
        if !isPersonalInfoValid { errors.append("Personal information is incomplete") }
        if !isTaxInfoValid { errors.append("Tax information is incomplete") }
        if !isFinancialInfoValid { errors.append("Financial information is incomplete") }
        if !isInvestmentExperienceValid { errors.append("Investment experience information is incomplete") }
        if !areLegalDeclarationsValid { errors.append("Legal declarations are incomplete") }

        return (errors.isEmpty, errors)
    }
}

// MARK: - User Creation Errors

enum UserCreationError: LocalizedError {
    case missingEmail
    case missingFirstName
    case missingLastName
    case missingPassword
    case missingDateOfBirth
    case termsNotAccepted
    case privacyPolicyNotAccepted

    var errorDescription: String? {
        switch self {
        case .missingEmail:
            return "Email address is required"
        case .missingFirstName:
            return "First name is required"
        case .missingLastName:
            return "Last name is required"
        case .missingPassword:
            return "Password is required"
        case .missingDateOfBirth:
            return "Date of birth is required"
        case .termsNotAccepted:
            return "Terms and conditions must be accepted"
        case .privacyPolicyNotAccepted:
            return "Privacy policy must be accepted"
        }
    }
}
