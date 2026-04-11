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
        generateCustomerNumber()
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
        let prefix = userRole == .trader ? TestConstants.customerIdPrefixTrader : TestConstants.customerIdPrefixInvestor
        let year = Calendar.current.component(.year, from: Date())
        let randomNumber = String(format: "%05d", Int.random(in: 1...99999))
        customerNumber = "\(prefix)-\(year)-\(randomNumber)"
    }

    // MARK: - Restore from Backend (Resume Flow)

    /// Hydrates form fields from data returned by `getOnboardingProgress`.
    /// Skips password / confirmPassword (never persisted) and UIImage fields.
    func restoreFromSavedData(_ data: SavedOnboardingData) {
        // Account
        if let v = data.accountType, let e = AccountType(rawValue: v) { accountType = e }
        if let v = data.userRole, let e = UserRole(rawValue: v) { userRole = e }

        // Contact (password intentionally omitted — never sent to backend)
        if let v = data.email, !v.isEmpty { email = v }
        if let v = data.phoneNumber, !v.isEmpty { phoneNumber = v }
        if let v = data.username, !v.isEmpty { username = v }

        // Personal
        if let v = data.salutation, let e = Salutation(rawValue: v) { salutation = e }
        if let v = data.academicTitle { academicTitle = v }
        if let v = data.firstName, !v.isEmpty { firstName = v }
        if let v = data.lastName, !v.isEmpty { lastName = v }
        if let v = data.streetAndNumber, !v.isEmpty { streetAndNumber = v }
        if let v = data.postalCode, !v.isEmpty { postalCode = v }
        if let v = data.city, !v.isEmpty { city = v }
        if let v = data.state { state = v }
        if let v = data.country, !v.isEmpty { country = v }
        if let v = data.placeOfBirth, !v.isEmpty { placeOfBirth = v }
        if let v = data.countryOfBirth, !v.isEmpty { countryOfBirth = v }
        if let v = data.dateOfBirth, let d = ISO8601DateFormatter().date(from: v) { dateOfBirth = d }

        // Citizenship & Tax
        if let v = data.isNotUSCitizen { isNotUSCitizen = v }
        if let v = data.nationality, !v.isEmpty { nationality = v }
        if let v = data.additionalNationalities { additionalNationalities = v }
        if let v = data.address { address = v }
        if let v = data.taxNumber, !v.isEmpty { taxNumber = v }
        if let v = data.additionalResidenceCountry { additionalResidenceCountry = v }

        // Identification (images excluded)
        if let v = data.identificationType, let e = IdentificationType(rawValue: v) { identificationType = e }

        // Financial
        if let v = data.employmentStatus, let e = EmploymentStatus(rawValue: v) { employmentStatus = e }
        if let v = data.income { income = v }
        if let v = data.incomeRange, let e = IncomeRange(rawValue: v) { incomeRange = e }
        if let v = data.incomeSources { incomeSources = v }
        if let v = data.otherIncomeSource { otherIncomeSource = v }
        if let v = data.cashAndLiquidAssets, let e = CashAndLiquidAssets(rawValue: v) { cashAndLiquidAssets = e }

        // Experience
        if let v = data.stocksTransactionsCount, let e = StocksTransactionCount(rawValue: v) { stocksTransactionsCount = e }
        if let v = data.stocksInvestmentAmount, let e = InvestmentAmount(rawValue: v) { stocksInvestmentAmount = e }
        if let v = data.etfsTransactionsCount, let e = ETFsTransactionCount(rawValue: v) { etfsTransactionsCount = e }
        if let v = data.etfsInvestmentAmount, let e = InvestmentAmount(rawValue: v) { etfsInvestmentAmount = e }
        if let v = data.derivativesTransactionsCount, let e = DerivativesTransactionCount(rawValue: v) { derivativesTransactionsCount = e }
        if let v = data.derivativesInvestmentAmount, let e = DerivativesInvestmentAmount(rawValue: v) { derivativesInvestmentAmount = e }
        if let v = data.derivativesHoldingPeriod, let e = HoldingPeriod(rawValue: v) { derivativesHoldingPeriod = e }
        if let v = data.otherAssets { otherAssets = v }

        // Risk & Return
        if let v = data.desiredReturn, let e = DesiredReturn(rawValue: v) { desiredReturn = e }
        if let v = data.finalRiskClass, let e = RiskClass(rawValue: v) { userSelectedRiskClass = e }

        // Declarations
        if let v = data.insiderTradingOptions { insiderTradingOptions = v }
        if let v = data.moneyLaunderingDeclaration { moneyLaunderingDeclaration = v }
        if let v = data.assetType, let e = AssetType(rawValue: v) { assetType = e }
        if let v = data.leveragedProductsExperience { leveragedProductsExperience = v }
        if let v = data.financialProductsExperience { financialProductsExperience = v }

        // Terms
        if let v = data.acceptedTerms { acceptedTerms = v }
        if let v = data.acceptedPrivacyPolicy { acceptedPrivacyPolicy = v }
        if let v = data.acceptedMarketingConsent { acceptedMarketingConsent = v }

        // Meta
        if let v = data.customerNumber ?? data.customerId, !v.isEmpty { customerNumber = v }
    }

    // MARK: - Pre-fill with Test Data (DEBUG only)
    #if DEBUG
    func prefillTestData() {
        email = "test@example.com"
        phoneNumber = "+49123456789"
        username = "testuser"
        password = TestConstants.password
        confirmPassword = TestConstants.password
        firstName = "Max"
        lastName = "Mustermann"
        streetAndNumber = "Musterstraße 123"
        postalCode = "12345"
        city = "Musterstadt"
        state = "Bayern"
        placeOfBirth = "München"
        taxNumber = "12345678901"
    }
    #endif
}
