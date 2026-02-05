import Foundation

struct User: Identifiable, Codable, Sendable {
    let id: String
    var customerId: String
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

    var lastLoginDate: Date?
    var createdAt: Date
    var updatedAt: Date

}
