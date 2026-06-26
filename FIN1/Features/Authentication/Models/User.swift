import Foundation

struct User: Identifiable, Codable, Sendable {
    let id: String
    /// Business Kundennummer (z. B. ANL-/TRD-…), nicht Parse `objectId`.
    var customerNumber: String
    var accountType: AccountType
    var email: String
    var username: String
    var phoneNumber: String
    var password: String
    var salutation: Salutation
    var academicTitle: String
    var firstName: String
    var lastName: String
    var streetAndNumber: String
    var postalCode: String
    var city: String
    var state: String
    var country: String
    var dateOfBirth: Date
    var placeOfBirth: String
    var countryOfBirth: String
    var role: UserRole
    var csrRole: CSRRole?  // Specific CSR role for customer service representatives
    var employmentStatus: EmploymentStatus
    var income: Double
    var incomeRange: IncomeRange
    var riskTolerance: Int // 1-10 scale

    // Address & Legal Information
    var address: String
    var nationality: String
    var additionalNationalities: String
    var taxNumber: String
    var additionalTaxResidences: String
    var isNotUSCitizen: Bool

    // Identification Documents
    var identificationType: IdentificationType?
    var passportFrontImageURL: String?
    var passportBackImageURL: String?
    var idCardFrontImageURL: String?
    var idCardBackImageURL: String?
    var identificationConfirmed: Bool = false

    // Address Verification
    var addressConfirmed: Bool = false
    var addressVerificationDocumentURL: String?

    // Experience & Financial Information
    var leveragedProductsExperience: Bool = false // For traders
    var financialProductsExperience: Bool = false // For investors
    var investmentExperience: Int = 0
    var tradingFrequency: Int = 0
    var investmentKnowledge: Int = 0
    var desiredReturn: DesiredReturn = .atLeastTenPercent

    // Declarations
    var insiderTradingOptions: [String: Bool] = [
        "Brokerage or Stock Exchange Employee": false,
        "Director or 10% Shareholder": false,
        "High-Ranking Official": false,
        "None of the above": true
    ]
    var moneyLaunderingDeclaration: Bool = false
    var assetType: AssetType = .privateAssets

    // Profile & Verification
    var profileImageURL: String?
    var isEmailVerified: Bool
    var isKYCCompleted: Bool
    var acceptedTerms: Bool
    var acceptedPrivacyPolicy: Bool
    var acceptedMarketingConsent: Bool

    // Terms Version Tracking
    var acceptedTermsVersion: String?
    var acceptedTermsDate: Date?
    var acceptedPrivacyPolicyVersion: String?
    var acceptedPrivacyPolicyDate: Date?

    // Role agreement tracking (Trader / Investor)
    var acceptedTraderAgreement: Bool = false
    var acceptedTraderAgreementVersion: String?
    var acceptedTraderAgreementDate: Date?
    var acceptedInvestorAgreement: Bool = false
    var acceptedInvestorAgreementVersion: String?
    var acceptedInvestorAgreementDate: Date?

    // Onboarding State (synced with backend)
    var onboardingCompleted: Bool = false
    var onboardingStep: String?
    var kycStatus: String?

    // Company KYB State (synced with backend)
    var companyKybCompleted: Bool = false
    var companyKybStep: String?
    var companyKybStatus: String?

    /// Post-onboarding version drift from `getUserMe` / `getRequiredReConsents` (session-only).
    var requiredReConsents: [RequiredReConsent]? = nil

    var lastLoginDate: Date?
    var createdAt: Date
    var updatedAt: Date
}

extension User {
    /// Technical person key for API queries — Parse `objectId` when available.
    var canonicalUserId: String { self.id }

    /// Read keys for backend fetch. After login uses a single Parse id (one query, no alias fan-out).
    var ledgerUserIdCandidates: [String] {
        if Self.isParseObjectId(self.id) {
            return [self.id]
        }
        let email = self.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if email.isEmpty {
            return [self.id]
        }
        return [self.id, UserFactory.stableUserId(for: email)]
    }

    private static func isParseObjectId(_ value: String) -> Bool {
        value.range(of: #"^[a-zA-Z0-9]{10}$"#, options: .regularExpression) != nil
    }

    /// Copy with a different identity key (e.g. Parse `objectId` after login).
    func withId(_ newId: String) -> User {
        guard newId != self.id else { return self }
        return User(
            id: newId,
            customerNumber: self.customerNumber,
            accountType: self.accountType,
            email: self.email,
            username: self.username,
            phoneNumber: self.phoneNumber,
            password: self.password,
            salutation: self.salutation,
            academicTitle: self.academicTitle,
            firstName: self.firstName,
            lastName: self.lastName,
            streetAndNumber: self.streetAndNumber,
            postalCode: self.postalCode,
            city: self.city,
            state: self.state,
            country: self.country,
            dateOfBirth: self.dateOfBirth,
            placeOfBirth: self.placeOfBirth,
            countryOfBirth: self.countryOfBirth,
            role: self.role,
            csrRole: self.csrRole,
            employmentStatus: self.employmentStatus,
            income: self.income,
            incomeRange: self.incomeRange,
            riskTolerance: self.riskTolerance,
            address: self.address,
            nationality: self.nationality,
            additionalNationalities: self.additionalNationalities,
            taxNumber: self.taxNumber,
            additionalTaxResidences: self.additionalTaxResidences,
            isNotUSCitizen: self.isNotUSCitizen,
            identificationType: self.identificationType,
            passportFrontImageURL: self.passportFrontImageURL,
            passportBackImageURL: self.passportBackImageURL,
            idCardFrontImageURL: self.idCardFrontImageURL,
            idCardBackImageURL: self.idCardBackImageURL,
            identificationConfirmed: self.identificationConfirmed,
            addressConfirmed: self.addressConfirmed,
            addressVerificationDocumentURL: self.addressVerificationDocumentURL,
            leveragedProductsExperience: self.leveragedProductsExperience,
            financialProductsExperience: self.financialProductsExperience,
            investmentExperience: self.investmentExperience,
            tradingFrequency: self.tradingFrequency,
            investmentKnowledge: self.investmentKnowledge,
            desiredReturn: self.desiredReturn,
            insiderTradingOptions: self.insiderTradingOptions,
            moneyLaunderingDeclaration: self.moneyLaunderingDeclaration,
            assetType: self.assetType,
            profileImageURL: self.profileImageURL,
            isEmailVerified: self.isEmailVerified,
            isKYCCompleted: self.isKYCCompleted,
            acceptedTerms: self.acceptedTerms,
            acceptedPrivacyPolicy: self.acceptedPrivacyPolicy,
            acceptedMarketingConsent: self.acceptedMarketingConsent,
            acceptedTermsVersion: self.acceptedTermsVersion,
            acceptedTermsDate: self.acceptedTermsDate,
            acceptedPrivacyPolicyVersion: self.acceptedPrivacyPolicyVersion,
            acceptedPrivacyPolicyDate: self.acceptedPrivacyPolicyDate,
            acceptedTraderAgreement: self.acceptedTraderAgreement,
            acceptedTraderAgreementVersion: self.acceptedTraderAgreementVersion,
            acceptedTraderAgreementDate: self.acceptedTraderAgreementDate,
            acceptedInvestorAgreement: self.acceptedInvestorAgreement,
            acceptedInvestorAgreementVersion: self.acceptedInvestorAgreementVersion,
            acceptedInvestorAgreementDate: self.acceptedInvestorAgreementDate,
            onboardingCompleted: self.onboardingCompleted,
            onboardingStep: self.onboardingStep,
            kycStatus: self.kycStatus,
            companyKybCompleted: self.companyKybCompleted,
            companyKybStep: self.companyKybStep,
            companyKybStatus: self.companyKybStatus,
            requiredReConsents: self.requiredReConsents,
            lastLoginDate: self.lastLoginDate,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt
        )
    }
}
