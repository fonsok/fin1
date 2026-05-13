import SwiftUI

// MARK: - Core SignUp Data Model

final class SignUpData: ObservableObject {
    // MARK: - Step 1: Account Type Selection
    @Published var accountType: AccountType = .individual
    @Published var userRole: UserRole = .investor

    // MARK: - Step 2: Contact Information
    @Published var email: String = ""
    @Published var phoneNumber: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""

    // MARK: - Step 3: Personal Information
    @Published var salutation: Salutation = .mr
    @Published var academicTitle: String = ""
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var streetAndNumber: String = ""
    @Published var postalCode: String = ""
    @Published var city: String = ""
    @Published var state: String = ""
    @Published var country: String = "Deutschland"
    @Published var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @Published var placeOfBirth: String = ""
    @Published var countryOfBirth: String = "Deutschland"

    // MARK: - Step 4: Citizenship & Tax Information
    @Published var isNotUSCitizen: Bool = true
    @Published var nationality: String = "Deutschland"
    @Published var additionalNationalities: String = ""

    // MARK: - Step 5: Additional Address & Legal Information
    @Published var address: String = ""
    @Published var taxNumber: String = ""
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

    // Kundennummer (automatically generated, business identifier)
    @Published var customerNumber: String = ""

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
        self.generateCustomerNumber()
    }

    // MARK: - Service Injection
    func injectServices(
        riskClassCalculationService: any RiskClassCalculationServiceProtocol,
        investmentExperienceCalculationService: any InvestmentExperienceCalculationServiceProtocol
    ) {
        self.riskClassCalculationService = riskClassCalculationService
        self.investmentExperienceCalculationService = investmentExperienceCalculationService
    }

    // MARK: - Kundennummer Generation
    private func generateCustomerNumber() {
        let prefix = self.userRole == .trader ? TestConstants.customerIdPrefixTrader : TestConstants.customerIdPrefixInvestor
        let year = Calendar.current.component(.year, from: Date())
        let randomNumber = String(format: "%05d", Int.random(in: 1...99_999))
        self.customerNumber = "\(prefix)-\(year)-\(randomNumber)"
    }

    // MARK: - Restore from Backend (Resume Flow)

    /// Hydrates form fields from data returned by `getOnboardingProgress`.
    /// Skips password / confirmPassword (never persisted) and UIImage fields.
    func restoreFromSavedData(_ data: SavedOnboardingData) {
        // Account
        if let v = data.accountType, let e = AccountType(rawValue: v) { self.accountType = e }
        if let v = data.userRole, let e = UserRole(rawValue: v) { self.userRole = e }

        // Contact (password intentionally omitted — never sent to backend)
        if let v = data.email, !v.isEmpty { self.email = v }
        if let v = data.phoneNumber, !v.isEmpty { self.phoneNumber = v }
        if let v = data.username, !v.isEmpty { self.username = v }

        // Personal
        if let v = data.salutation, let e = Salutation(rawValue: v) { self.salutation = e }
        if let v = data.academicTitle { self.academicTitle = v }
        if let v = data.firstName, !v.isEmpty { self.firstName = v }
        if let v = data.lastName, !v.isEmpty { self.lastName = v }
        if let v = data.streetAndNumber, !v.isEmpty { self.streetAndNumber = v }
        if let v = data.postalCode, !v.isEmpty { self.postalCode = v }
        if let v = data.city, !v.isEmpty { self.city = v }
        if let v = data.state { self.state = v }
        if let v = data.country, !v.isEmpty { self.country = v }
        if let v = data.placeOfBirth, !v.isEmpty { self.placeOfBirth = v }
        if let v = data.countryOfBirth, !v.isEmpty { self.countryOfBirth = v }
        if let v = data.dateOfBirth, let d = ISO8601DateFormatter().date(from: v) { self.dateOfBirth = d }

        // Citizenship & Tax
        if let v = data.isNotUSCitizen { self.isNotUSCitizen = v }
        if let v = data.nationality, !v.isEmpty { self.nationality = v }
        if let v = data.additionalNationalities { self.additionalNationalities = v }
        if let v = data.address { self.address = v }
        if let v = data.taxNumber, !v.isEmpty { self.taxNumber = v }
        if let v = data.additionalResidenceCountry { self.additionalResidenceCountry = v }

        // Identification (images excluded)
        if let v = data.identificationType, let e = IdentificationType(rawValue: v) { self.identificationType = e }

        // Financial
        if let v = data.employmentStatus, let e = EmploymentStatus(rawValue: v) { self.employmentStatus = e }
        if let v = data.income { self.income = v }
        if let v = data.incomeRange, let e = IncomeRange(rawValue: v) { self.incomeRange = e }
        if let v = data.incomeSources { self.incomeSources = v }
        if let v = data.otherIncomeSource { self.otherIncomeSource = v }
        if let v = data.cashAndLiquidAssets, let e = CashAndLiquidAssets(rawValue: v) { self.cashAndLiquidAssets = e }

        // Experience
        if let v = data.stocksTransactionsCount, let e = StocksTransactionCount(rawValue: v) { self.stocksTransactionsCount = e }
        if let v = data.stocksInvestmentAmount, let e = InvestmentAmount(rawValue: v) { self.stocksInvestmentAmount = e }
        if let v = data.etfsTransactionsCount, let e = ETFsTransactionCount(rawValue: v) { self.etfsTransactionsCount = e }
        if let v = data.etfsInvestmentAmount, let e = InvestmentAmount(rawValue: v) { self.etfsInvestmentAmount = e }
        if let v = data.derivativesTransactionsCount, let e = DerivativesTransactionCount(rawValue: v) { self.derivativesTransactionsCount = e }
        if let v = data.derivativesInvestmentAmount, let e = DerivativesInvestmentAmount(rawValue: v) { self.derivativesInvestmentAmount = e }
        if let v = data.derivativesHoldingPeriod, let e = HoldingPeriod(rawValue: v) { self.derivativesHoldingPeriod = e }
        if let v = data.otherAssets { self.otherAssets = v }

        // Risk & Return
        if let v = data.desiredReturn, let e = DesiredReturn(rawValue: v) { self.desiredReturn = e }
        if let v = data.finalRiskClass, let e = RiskClass(rawValue: v) { self.userSelectedRiskClass = e }

        // Declarations
        if let v = data.insiderTradingOptions { self.insiderTradingOptions = v }
        if let v = data.moneyLaunderingDeclaration { self.moneyLaunderingDeclaration = v }
        if let v = data.assetType, let e = AssetType(rawValue: v) { self.assetType = e }
        if let v = data.leveragedProductsExperience { self.leveragedProductsExperience = v }
        if let v = data.financialProductsExperience { self.financialProductsExperience = v }

        // Terms
        if let v = data.acceptedTerms { self.acceptedTerms = v }
        if let v = data.acceptedPrivacyPolicy { self.acceptedPrivacyPolicy = v }
        if let v = data.acceptedMarketingConsent { self.acceptedMarketingConsent = v }

        // Meta
        if let v = data.customerNumber ?? data.customerId, !v.isEmpty { self.customerNumber = v }
    }

    // MARK: - Pre-fill with Test Data (DEBUG only)
    #if DEBUG
    func prefillTestData() {
        self.email = "test@example.com"
        self.phoneNumber = "+49123456789"
        self.username = "testuser"
        self.password = TestConstants.password
        self.confirmPassword = TestConstants.password
        self.firstName = "Max"
        self.lastName = "Mustermann"
        self.streetAndNumber = "Musterstraße 123"
        self.postalCode = "12345"
        self.city = "Musterstadt"
        self.state = "Bayern"
        self.placeOfBirth = "München"
        self.taxNumber = "12345678901"
    }
    #endif
}
