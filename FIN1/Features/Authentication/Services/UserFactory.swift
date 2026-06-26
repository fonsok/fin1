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
        // Parse session and Cloud Code use `_User.objectId`; keep local `User.id` aligned
        // so Investment.investorId / ledger reads match `collectLedgerUserIdCandidates`.
        if !response.objectId.isEmpty {
            user = user.withId(response.objectId)
        }
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
        if let id = me.id?.trimmingCharacters(in: .whitespacesAndNewlines),
           !id.isEmpty,
           id.range(of: #"^[a-zA-Z0-9]{10}$"#, options: .regularExpression) != nil {
            user = user.withId(id)
        }
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
            // Never downgrade a locally completed session when getUserMe lags behind completeOnboardingStep.
            user.onboardingCompleted = user.onboardingCompleted || ob
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
        if let riskTolerance = me.riskTolerance {
            user.riskTolerance = riskTolerance
        }
        if let acceptedTerms = me.acceptedTerms {
            user.acceptedTerms = acceptedTerms
        }
        if let acceptedPrivacyPolicy = me.acceptedPrivacyPolicy {
            user.acceptedPrivacyPolicy = acceptedPrivacyPolicy
        }
        if let version = me.acceptedTermsVersion, !version.isEmpty {
            user.acceptedTermsVersion = version
        }
        if let version = me.acceptedPrivacyPolicyVersion, !version.isEmpty {
            user.acceptedPrivacyPolicyVersion = version
        }
        if let dateStr = me.acceptedTermsDate {
            user.acceptedTermsDate = Self.parseISO8601Date(dateStr) ?? user.acceptedTermsDate
        }
        if let dateStr = me.acceptedPrivacyPolicyDate {
            user.acceptedPrivacyPolicyDate = Self.parseISO8601Date(dateStr) ?? user.acceptedPrivacyPolicyDate
        }
        if let acceptedTraderAgreement = me.acceptedTraderAgreement {
            user.acceptedTraderAgreement = user.acceptedTraderAgreement || acceptedTraderAgreement
        }
        if let version = me.acceptedTraderAgreementVersion, !version.isEmpty {
            user.acceptedTraderAgreementVersion = version
        }
        if let dateStr = me.acceptedTraderAgreementDate {
            user.acceptedTraderAgreementDate = Self.parseISO8601Date(dateStr) ?? user.acceptedTraderAgreementDate
        }
        if let acceptedInvestorAgreement = me.acceptedInvestorAgreement {
            user.acceptedInvestorAgreement = user.acceptedInvestorAgreement || acceptedInvestorAgreement
        }
        if let version = me.acceptedInvestorAgreementVersion, !version.isEmpty {
            user.acceptedInvestorAgreementVersion = version
        }
        if let dateStr = me.acceptedInvestorAgreementDate {
            user.acceptedInvestorAgreementDate = Self.parseISO8601Date(dateStr) ?? user.acceptedInvestorAgreementDate
        }
        if me.roleAgreementAccepted == true {
            switch user.role {
            case .trader:
                user.acceptedTraderAgreement = true
            case .investor:
                user.acceptedInvestorAgreement = true
            default:
                break
            }
        }
    }

    private static func parseISO8601Date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    static func createUser(from email: String, password: String) -> User {
        let isTrader = email.contains("trader")
        let userRole: UserRole = isTrader ? .trader : .investor
        let customerPrefix = isTrader ? TestConstants.customerIdPrefixTrader : TestConstants.customerIdPrefixInvestor

        return User(
            id: self.stableUserId(for: email),
            customerNumber: "\(customerPrefix)-\(Calendar.current.component(.year, from: Date()))-\(String(format: "%05d", Int.random(in: 1...99_999)))",
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
            income: 75_000,
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
