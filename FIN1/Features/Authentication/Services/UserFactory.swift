import Foundation

// MARK: - User Factory
/// Handles user creation and test user generation
struct UserFactory {

    // MARK: - Regular User Creation
    static func stableUserId(for email: String) -> String {
        // Use a deterministic ID derived from email to keep identity stable across sessions
        return "user:\(email.lowercased())"
    }

    /// Overlays server-provided fields from the login response onto a locally-created User.
    static func applyLoginResponse(_ response: ParseLoginResponse, to user: inout User) {
        if let accountType = response.accountType, let at = AccountType(rawValue: accountType) {
            user.accountType = at
        }
        if let role = response.role, let r = UserRole(rawValue: role) {
            user.role = r
        }
        if let firstName = response.firstName, !firstName.isEmpty {
            user.firstName = firstName
        }
        if let lastName = response.lastName, !lastName.isEmpty {
            user.lastName = lastName
        }
        user.companyKybCompleted = response.companyKybCompleted ?? false
        user.companyKybStep = response.companyKybStep
        user.companyKybStatus = response.companyKybStatus
        user.onboardingCompleted = response.onboardingCompleted ?? false
        user.onboardingStep = response.onboardingStep
    }

    /// Overlays fields from `getUserMe` (`ParseUserMeResponse`) onto the local `User`.
    static func applyUserMeResponse(_ me: ParseUserMeResponse, to user: inout User) {
        if let cn = me.customerNumber, !cn.isEmpty {
            user.customerNumber = cn
        }
        if let k = me.kycStatus {
            user.kycStatus = k
        }
        if let r = me.role, let role = UserRole(rawValue: r) {
            user.role = role
        }
        if let e = me.email, !e.isEmpty {
            user.email = e
        }
        if let ob = me.onboardingCompleted {
            user.onboardingCompleted = ob
        }
        if let at = me.accountType, let accountType = AccountType(rawValue: at) {
            user.accountType = accountType
        }
        if let ckc = me.companyKybCompleted {
            user.companyKybCompleted = ckc
        }
        user.companyKybStep = me.companyKybStep
        user.companyKybStatus = me.companyKybStatus
        user.onboardingStep = me.onboardingStep
    }

    static func createUser(from email: String, password: String) -> User {
        let isTrader = email.contains("trader")
        let userRole: UserRole = isTrader ? .trader : .investor
        let customerPrefix = isTrader ? TestConstants.customerIdPrefixTrader : TestConstants.customerIdPrefixInvestor

        return User(
            id: stableUserId(for: email),
            customerNumber: "\(customerPrefix)-\(Calendar.current.component(.year, from: Date()))-\(String(format: "%05d", Int.random(in: 1...99999)))",
            accountType: .individual,
            email: email,
            username: email.components(separatedBy: "@").first ?? "user",
            phoneNumber: "+1234567890",
            password: password,
            salutation: .mr,
            academicTitle: "",
            firstName: isTrader ? "Trader" : "Regular",
            lastName: "User",
            streetAndNumber: "123 Main St",
            postalCode: "10001",
            city: "New York",
            state: "NY",
            country: "United States",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date(),
            placeOfBirth: "New York",
            countryOfBirth: "United States",
            role: userRole,
            employmentStatus: .employed,
            income: 75000,
            incomeRange: .middle,
            riskTolerance: 3,
            address: "123 Main St",
            nationality: "American",
            additionalNationalities: "",
            taxNumber: "123-45-6789",
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
            leveragedProductsExperience: isTrader,
            financialProductsExperience: !isTrader,
            investmentExperience: isTrader ? 0 : 2,
            tradingFrequency: isTrader ? 1 : 0,
            investmentKnowledge: isTrader ? 0 : 2,
            desiredReturn: isTrader ? .atLeastHundredPercent : .atLeastTenPercent,
            insiderTradingOptions: [
                "Brokerage or Stock Exchange Employee": false,
                "Director or 10% Shareholder": false,
                "High-Ranking Official": false,
                "None of the above": true
            ],
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

}
