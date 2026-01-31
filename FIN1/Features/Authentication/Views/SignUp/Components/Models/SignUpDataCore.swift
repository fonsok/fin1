import SwiftUI

// MARK: - Core SignUp Data Model

final class SignUpData: ObservableObject {
    // MARK: - Step 1: Account Type Selection
    @Published var accountType: AccountType = .individual
    @Published var userRole: UserRole = .investor

    // MARK: - Step 2: Contact Information
    @Published var email: String = "test@example.com"
    @Published var phoneNumber: String = "+49123456789"
    @Published var username: String = "user"
    @Published var password: String = "TestPassword123!"
    @Published var confirmPassword: String = "TestPassword123!"

    // MARK: - Step 3: Personal Information
    @Published var salutation: Salutation = .mr
    @Published var academicTitle: String = ""
    @Published var firstName: String = "Max"
    @Published var lastName: String = "Mustermann"
    @Published var streetAndNumber: String = "Musterstraße 123"
    @Published var postalCode: String = "12345"
    @Published var city: String = "Musterstadt"
    @Published var state: String = "Bayern"
    @Published var country: String = "Deutschland"
    @Published var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @Published var placeOfBirth: String = "München"
    @Published var countryOfBirth: String = "Deutschland"

    // MARK: - Step 4: Citizenship & Tax Information
    @Published var isNotUSCitizen: Bool = true
    @Published var nationality: String = "Deutschland"
    @Published var additionalNationalities: String = ""

    // MARK: - Step 5: Additional Address & Legal Information
    @Published var address: String = ""
    @Published var taxNumber: String = "12345678901"
    @Published var additionalResidenceCountry: String = ""
    @Published var additionalTaxNumber: String = ""
    @Published var showAdditionalFields: Bool = false

    // MARK: - Step 6-9: Identification Documents
    @Published var identificationType: IdentificationType = .passport
    @Published var passportFrontImage: UIImage?
    @Published var passportBackImage: UIImage?
    @Published var idCardFrontImage: UIImage?
    @Published var idCardBackImage: UIImage?
    @Published var identificationConfirmed: Bool = false

    // MARK: - Step 10-11: Address Verification
    @Published var addressConfirmed: Bool = false
    @Published var addressVerificationDocument: UIImage?

    // MARK: - Step 12: Financial Information
    @Published var employmentStatus: EmploymentStatus = .employed
    @Published var income: String = ""
    @Published var incomeRange: IncomeRange = .middle

    // Income Sources (multiple selection)
    @Published var incomeSources: [String: Bool] = [
        "Settlement": false,
        "Inheritance": false,
        "Savings": false,
        "Financial contributions to family": false,
        "Salary": false,
        "Pension": false,
        "Assets": false,
        "Other (please specify)": false
    ]
    @Published var otherIncomeSource: String = ""

    // Cash and Liquid Assets
    @Published var cashAndLiquidAssets: CashAndLiquidAssets = .lessThan10k

    // MARK: - Step 13: Investment Experience
    // Stocks
    @Published var stocksTransactionsCount: StocksTransactionCount = .none
    @Published var stocksInvestmentAmount: InvestmentAmount = .hundredToTenThousand

    // Investment funds, ETFs
    @Published var etfsTransactionsCount: ETFsTransactionCount = .none
    @Published var etfsInvestmentAmount: InvestmentAmount = .hundredToTenThousand

    // Certificates and derivatives
    @Published var derivativesTransactionsCount: DerivativesTransactionCount = .none
    @Published var derivativesInvestmentAmount: DerivativesInvestmentAmount = .zeroToThousand
    @Published var derivativesHoldingPeriod: HoldingPeriod = .monthsToYears

    // Other assets
    @Published var otherAssets: [String: Bool] = [
        "Real estate": false,
        "Gold, silver": false,
        "No": false
    ]

    // MARK: - Step 14: Desired Return
    @Published var desiredReturn: DesiredReturn = .atLeastTenPercent

    // MARK: - Step 15-16: Declarations
    @Published var insiderTradingOptions: [String: Bool] = [
        "Brokerage or Stock Exchange Employee": false,
        "Director or 10% Shareholder": false,
        "High-Ranking Official": false,
        "None of the above": true
    ]
    @Published var moneyLaunderingDeclaration: Bool = false
    @Published var assetType: AssetType = .privateAssets

    // Experience flags
    @Published var leveragedProductsExperience: Bool = false
    @Published var financialProductsExperience: Bool = false

    // MARK: - Step 17: Terms & Conditions
    @Published var acceptedTerms: Bool = false
    @Published var acceptedPrivacyPolicy: Bool = false
    @Published var acceptedMarketingConsent: Bool = false

    // MARK: - Risk Class Properties
    @Published var userSelectedRiskClass: RiskClass?

    // Customer ID (automatically generated)
    @Published var customerId: String = ""

    // MARK: - Services (injected)
    var riskClassCalculationService: (any RiskClassCalculationServiceProtocol)?
    var investmentExperienceCalculationService: (any InvestmentExperienceCalculationServiceProtocol)?

    // MARK: - Initialization
    init(
        riskClassCalculationService: (any RiskClassCalculationServiceProtocol)? = nil,
        investmentExperienceCalculationService: (any InvestmentExperienceCalculationServiceProtocol)? = nil
    ) {
        self.riskClassCalculationService = riskClassCalculationService
        self.investmentExperienceCalculationService = investmentExperienceCalculationService
        generateCustomerId()
    }

    // MARK: - Service Injection
    func injectServices(
        riskClassCalculationService: any RiskClassCalculationServiceProtocol,
        investmentExperienceCalculationService: any InvestmentExperienceCalculationServiceProtocol
    ) {
        self.riskClassCalculationService = riskClassCalculationService
        self.investmentExperienceCalculationService = investmentExperienceCalculationService
    }

    // MARK: - Customer ID Generation
    private func generateCustomerId() {
        // Generate a unique customer ID with format: <PREFIX>-YYYY-XXXXX
        let year = Calendar.current.component(.year, from: Date())
        let randomNumber = String(format: "%05d", Int.random(in: 1...99999))
        customerId = "\(LegalIdentity.documentPrefix)-\(year)-\(randomNumber)"
    }
}
