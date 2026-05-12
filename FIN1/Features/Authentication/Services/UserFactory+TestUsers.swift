import Foundation

#if DEBUG
extension UserFactory {
    // MARK: - Test User Creation

    static func createTestUser(email: String, password: String) -> User {
        let signUpData = SignUpData()

        if email.contains("admin") {
            return makeAdminTestUser(email: email, password: password, customerNumber: signUpData.customerNumber)
        }

        if email.contains("csr") || email.contains("customerService") || email.contains("kundenberater") {
            return makeCSRTestUser(email: email, password: password, customerNumber: signUpData.customerNumber)
        }

        return makeInvestorOrTraderTestUser(email: email, password: password, signUpData: signUpData)
    }

    private static func makeAdminTestUser(email: String, password: String, customerNumber: String) -> User {
        User(
            id: stableUserId(for: email),
            customerNumber: customerNumber,
            accountType: .company,
            email: email,
            username: "admin",
            phoneNumber: "+1234567890",
            password: password,
            salutation: .mr,
            academicTitle: "",
            firstName: "System",
            lastName: "Admin",
            streetAndNumber: "1 Admin Way",
            postalCode: "10000",
            city: "Berlin",
            state: "BE",
            country: "Germany",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date(),
            placeOfBirth: "Berlin",
            countryOfBirth: "Germany",
            role: .admin,
            employmentStatus: .employed,
            income: 0,
            incomeRange: .middle,
            riskTolerance: 1,
            address: "1 Admin Way",
            nationality: "German",
            additionalNationalities: "",
            taxNumber: "DE-ADMIN-000",
            additionalTaxResidences: "",
            isNotUSCitizen: true,
            identificationType: .passport,
            passportFrontImageURL: nil,
            passportBackImageURL: nil,
            idCardFrontImageURL: nil,
            idCardBackImageURL: nil,
            identificationConfirmed: true,
            addressConfirmed: true,
            addressVerificationDocumentURL: nil,
            leveragedProductsExperience: false,
            financialProductsExperience: true,
            investmentExperience: 0,
            tradingFrequency: 0,
            investmentKnowledge: 0,
            desiredReturn: .atLeastTenPercent,
            insiderTradingOptions: ["None of the above": true],
            moneyLaunderingDeclaration: true,
            assetType: .privateAssets,
            profileImageURL: nil,
            isEmailVerified: true,
            isKYCCompleted: true,
            acceptedTerms: true,
            acceptedPrivacyPolicy: true,
            acceptedMarketingConsent: true,
            acceptedTermsVersion: TermsVersionConstants.currentTermsVersion,
            acceptedTermsDate: Date(),
            acceptedPrivacyPolicyVersion: TermsVersionConstants.currentPrivacyPolicyVersion,
            acceptedPrivacyPolicyDate: Date(),
            lastLoginDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private static func makeCSRTestUser(email: String, password: String, customerNumber: String) -> User {
        let csrInfo = getCSRInfo(from: email)
        return User(
            id: stableUserId(for: email),
            customerNumber: customerNumber,
            accountType: .company,
            email: email,
            username: csrInfo.username,
            phoneNumber: "+1234567890",
            password: password,
            salutation: csrInfo.salutation,
            academicTitle: "",
            firstName: csrInfo.firstName,
            lastName: csrInfo.lastName,
            streetAndNumber: "1 Support Street",
            postalCode: "10000",
            city: "Berlin",
            state: "BE",
            country: "Germany",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date(),
            placeOfBirth: "Berlin",
            countryOfBirth: "Germany",
            role: .customerService,
            csrRole: csrInfo.csrRole,
            employmentStatus: .employed,
            income: 0,
            incomeRange: .middle,
            riskTolerance: 1,
            address: "1 Support Street",
            nationality: "German",
            additionalNationalities: "",
            taxNumber: "DE-CSR-\(csrInfo.roleCode)",
            additionalTaxResidences: "",
            isNotUSCitizen: true,
            identificationType: .passport,
            passportFrontImageURL: nil,
            passportBackImageURL: nil,
            idCardFrontImageURL: nil,
            idCardBackImageURL: nil,
            identificationConfirmed: true,
            addressConfirmed: true,
            addressVerificationDocumentURL: nil,
            leveragedProductsExperience: false,
            financialProductsExperience: true,
            investmentExperience: 0,
            tradingFrequency: 0,
            investmentKnowledge: 0,
            desiredReturn: .atLeastTenPercent,
            insiderTradingOptions: ["None of the above": true],
            moneyLaunderingDeclaration: true,
            assetType: .privateAssets,
            profileImageURL: nil,
            isEmailVerified: true,
            isKYCCompleted: true,
            acceptedTerms: true,
            acceptedPrivacyPolicy: true,
            acceptedMarketingConsent: true,
            acceptedTermsVersion: TermsVersionConstants.currentTermsVersion,
            acceptedTermsDate: Date(),
            acceptedPrivacyPolicyVersion: TermsVersionConstants.currentPrivacyPolicyVersion,
            acceptedPrivacyPolicyDate: Date(),
            lastLoginDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private static func makeInvestorOrTraderTestUser(email: String, password: String, signUpData: SignUpData) -> User {
        let isTrader = email.contains("trader")
        let userNumber = extractUserNumber(from: email)

        if isTrader {
            signUpData.userRole = .trader
            signUpData.desiredReturn = .atLeastHundredPercent
            signUpData.derivativesTransactionsCount = .fiftyPlus
            signUpData.derivativesHoldingPeriod = .minutesToHours
            signUpData.leveragedProductsExperience = true
        } else {
            signUpData.userRole = .investor
            signUpData.financialProductsExperience = true
        }

        signUpData.email = email
        let firstName = isTrader ? getTraderFirstName(for: userNumber) : getInvestorFirstName(for: userNumber)
        let lastName = isTrader ? getTraderLastName(for: userNumber) : getInvestorLastName(for: userNumber)
        signUpData.firstName = firstName
        signUpData.lastName = lastName
        signUpData.username = "\(firstName.lowercased().prefix(1))\(lastName.lowercased())"
        signUpData.moneyLaunderingDeclaration = true
        signUpData.acceptedTerms = true
        signUpData.acceptedPrivacyPolicy = true
        signUpData.acceptedMarketingConsent = true

        return User(
            id: stableUserId(for: email),
            customerNumber: signUpData.customerNumber,
            accountType: signUpData.accountType,
            email: email,
            username: signUpData.username.isEmpty ? email.components(separatedBy: "@").first ?? "user" : signUpData.username,
            phoneNumber: signUpData.phoneNumber,
            password: password,
            salutation: signUpData.salutation,
            academicTitle: signUpData.academicTitle,
            firstName: signUpData.firstName,
            lastName: signUpData.lastName,
            streetAndNumber: signUpData.streetAndNumber,
            postalCode: signUpData.postalCode,
            city: signUpData.city,
            state: signUpData.state,
            country: signUpData.country,
            dateOfBirth: signUpData.dateOfBirth,
            placeOfBirth: signUpData.placeOfBirth,
            countryOfBirth: signUpData.countryOfBirth,
            role: signUpData.userRole,
            employmentStatus: signUpData.employmentStatus,
            income: Double(signUpData.income) ?? 0,
            incomeRange: signUpData.incomeRange,
            riskTolerance: signUpData.finalRiskClass.rawValue,
            address: signUpData.address,
            nationality: signUpData.nationality,
            additionalNationalities: signUpData.additionalNationalities,
            taxNumber: signUpData.taxNumber,
            additionalTaxResidences: signUpData.additionalResidenceCountry,
            isNotUSCitizen: signUpData.isNotUSCitizen,
            identificationType: signUpData.identificationType,
            passportFrontImageURL: nil,
            passportBackImageURL: nil,
            idCardFrontImageURL: nil,
            idCardBackImageURL: nil,
            identificationConfirmed: true,
            addressConfirmed: true,
            addressVerificationDocumentURL: nil,
            leveragedProductsExperience: signUpData.leveragedProductsExperience,
            financialProductsExperience: signUpData.financialProductsExperience,
            investmentExperience: 0,
            tradingFrequency: 0,
            investmentKnowledge: 0,
            desiredReturn: signUpData.desiredReturn,
            insiderTradingOptions: signUpData.insiderTradingOptions,
            moneyLaunderingDeclaration: signUpData.moneyLaunderingDeclaration,
            assetType: signUpData.assetType,
            profileImageURL: nil,
            isEmailVerified: true,
            isKYCCompleted: true,
            acceptedTerms: signUpData.acceptedTerms,
            acceptedPrivacyPolicy: signUpData.acceptedPrivacyPolicy,
            acceptedMarketingConsent: signUpData.acceptedMarketingConsent,
            acceptedTermsVersion: signUpData.acceptedTerms ? TermsVersionConstants.currentTermsVersion : nil,
            acceptedTermsDate: signUpData.acceptedTerms ? Date() : nil,
            acceptedPrivacyPolicyVersion: signUpData.acceptedPrivacyPolicy ? TermsVersionConstants.currentPrivacyPolicyVersion : nil,
            acceptedPrivacyPolicyDate: signUpData.acceptedPrivacyPolicy ? Date() : nil,
            lastLoginDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
#endif
