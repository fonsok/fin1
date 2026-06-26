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

    // MARK: - Step 15: Financial Information
    @Published var employmentStatus: EmploymentStatus?
    @Published var income: String = ""
    @Published var incomeRange: IncomeRange?

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
    @Published var cashAndLiquidAssets: CashAndLiquidAssets?

    // MARK: - Step 16: Investment Experience
    // Stocks
    @Published var stocksTransactionsCount: StocksTransactionCount?
    @Published var stocksInvestmentAmount: InvestmentAmount?

    // Investment funds, ETFs
    @Published var etfsTransactionsCount: ETFsTransactionCount?
    @Published var etfsInvestmentAmount: InvestmentAmount?

    // Certificates and derivatives
    @Published var derivativesTransactionsCount: DerivativesTransactionCount?
    @Published var derivativesInvestmentAmount: DerivativesInvestmentAmount?
    @Published var derivativesHoldingPeriod: HoldingPeriod?

    // Other assets
    @Published var otherAssets: [String: Bool] = [
        "Real estate": false,
        "Gold, silver": false,
        "No": false
    ]

    // MARK: - Step 14: Desired Return
    @Published var desiredReturn: DesiredReturn = .atLeastTenPercent
    /// Explicit Ja/Nein on step 17 — `false` assigns risk class 1 at summary; either answer required to continue.
    @Published var leveragedProductsTotalLossRiskAcknowledged: Bool?
    /// Answers keyed by question id (e.g. `put_dow_jones_falling` → `A`).
    @Published var leveragedProductsKnowledgeTestAnswers: [String: String] = [:]

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

    // MARK: - Role Agreement (Trader / Investor Gate 2)
    @Published var acceptedTraderAgreement: Bool = false
    @Published var acceptedTraderAgreementVersion: String?
    @Published var acceptedInvestorAgreement: Bool = false
    @Published var acceptedInvestorAgreementVersion: String?

    /// Legal Gate 1 + 2: both AGB and DSE must be accepted (single client-side rule).
    var hasRequiredLegalConsents: Bool {
        self.acceptedTerms && self.acceptedPrivacyPolicy
    }

    /// Role-specific agreement must be accepted before registration completion.
    var hasRequiredRoleAgreement: Bool {
        switch self.userRole {
        case .trader:
            return self.acceptedTraderAgreement
        case .investor:
            return self.acceptedInvestorAgreement
        default:
            return true
        }
    }

    func markRoleAgreementAccepted(for role: UserRole, version: String) {
        switch role {
        case .trader:
            self.acceptedTraderAgreement = true
            self.acceptedTraderAgreementVersion = version
        case .investor:
            self.acceptedInvestorAgreement = true
            self.acceptedInvestorAgreementVersion = version
        default:
            break
        }
    }

    // MARK: - Risk Class Properties
    @Published var userSelectedRiskClass: RiskClass?

    // Kundennummer (automatically generated, business identifier)
    @Published var customerNumber: String = ""

    // MARK: - Services (injected; risk class service defaults for previews/tests)
    private(set) var riskClassCalculationService: any RiskClassCalculationServiceProtocol
    var investmentExperienceCalculationService: (any InvestmentExperienceCalculationServiceProtocol)?

    // MARK: - Initialization
    init(
        riskClassCalculationService: (any RiskClassCalculationServiceProtocol)? = nil,
        investmentExperienceCalculationService: (any InvestmentExperienceCalculationServiceProtocol)? = nil
    ) {
        self.riskClassCalculationService = riskClassCalculationService ?? RiskClassCalculationService()
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
    /// Step-15/16 pickers are only restored once the user has moved past that step,
    /// so legacy default values from older app versions are not shown as selections.
    func restoreFromSavedData(
        _ data: SavedOnboardingData,
        resumeStep: SignUpStep? = nil,
        lockAccountRole: Bool = false
    ) {
        self.restoreAccountFromSavedData(data, lockRole: lockAccountRole)
        self.restoreContactFromSavedData(data)
        self.restorePersonalFromSavedData(data)
        self.restoreCitizenshipAndTaxFromSavedData(data)
        self.restoreIdentificationFromSavedData(data)

        if SignUpLegacyPickerDefaults.shouldRestoreFinancialPickers(
            resumeStep: resumeStep,
            savedData: data
        ) {
            self.restoreFinancialFromSavedData(data)
        } else {
            self.clearStep15PickerSelections()
        }

        if SignUpLegacyPickerDefaults.shouldRestoreExperiencePickers(
            resumeStep: resumeStep,
            savedData: data
        ) {
            self.restoreExperienceFromSavedData(data)
        } else {
            self.clearStep16PickerSelections()
        }

        self.restoreRiskAndReturnFromSavedData(data)
        self.restoreDeclarationsFromSavedData(data)
        self.restoreTermsFromSavedData(data)
        self.restoreMetaFromSavedData(data)
    }

    /// Resets all step-15 dropdowns to the unset state (`---`).
    func clearStep15PickerSelections() {
        self.employmentStatus = nil
        self.incomeRange = nil
        self.cashAndLiquidAssets = nil
    }

    /// Resets all step-16 dropdowns to the unset state (`---`).
    func clearStep16PickerSelections() {
        self.stocksTransactionsCount = nil
        self.stocksInvestmentAmount = nil
        self.etfsTransactionsCount = nil
        self.etfsInvestmentAmount = nil
        self.derivativesTransactionsCount = nil
        self.derivativesInvestmentAmount = nil
        self.derivativesHoldingPeriod = nil
    }

    /// Resets step-15 and step-16 dropdowns to the unset state (`---`).
    func clearStep15And16PickerSelections() {
        self.clearStep15PickerSelections()
        self.clearStep16PickerSelections()
    }

    private func restoreAccountFromSavedData(_ data: SavedOnboardingData, lockRole: Bool = false) {
        if let v = data.accountType, let e = AccountType(rawValue: v) { self.accountType = e }
        if !lockRole, let v = data.userRole, let e = UserRole(rawValue: v) { self.userRole = e }
    }

    private func restoreContactFromSavedData(_ data: SavedOnboardingData) {
        // Password intentionally omitted — never sent to backend
        if let v = data.email, !v.isEmpty { self.email = v }
        if let v = data.phoneNumber, !v.isEmpty { self.phoneNumber = v }
        if let v = data.username, !v.isEmpty { self.username = v }
    }

    private func restorePersonalFromSavedData(_ data: SavedOnboardingData) {
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
    }

    private func restoreCitizenshipAndTaxFromSavedData(_ data: SavedOnboardingData) {
        if let v = data.isNotUSCitizen { self.isNotUSCitizen = v }
        if let v = data.nationality, !v.isEmpty { self.nationality = v }
        if let v = data.additionalNationalities { self.additionalNationalities = v }
        if let v = data.address { self.address = v }
        if let v = data.taxNumber, !v.isEmpty { self.taxNumber = v }
        if let v = data.additionalResidenceCountry { self.additionalResidenceCountry = v }
    }

    private func restoreIdentificationFromSavedData(_ data: SavedOnboardingData) {
        if let v = data.identificationType, let e = IdentificationType(rawValue: v) {
            self.identificationType = e
        }
    }

    private func restoreFinancialFromSavedData(_ data: SavedOnboardingData) {
        if let v = data.employmentStatus, let e = EmploymentStatus(rawValue: v) { self.employmentStatus = e }
        if let v = data.income { self.income = v }
        if let v = data.incomeRange, let e = IncomeRange(rawValue: v) { self.incomeRange = e }
        if let v = data.incomeSources { self.incomeSources = v }
        if let v = data.otherIncomeSource { self.otherIncomeSource = v }
        if let v = data.cashAndLiquidAssets, let e = CashAndLiquidAssets(rawValue: v) { self.cashAndLiquidAssets = e }
    }

    private func restoreExperienceFromSavedData(_ data: SavedOnboardingData) {
        if let v = data.stocksTransactionsCount, let e = StocksTransactionCount(rawValue: v) {
            self.stocksTransactionsCount = e
        }
        if let v = data.stocksInvestmentAmount, let e = InvestmentAmount(rawValue: v) {
            self.stocksInvestmentAmount = e
        }
        if let v = data.etfsTransactionsCount, let e = ETFsTransactionCount(rawValue: v) {
            self.etfsTransactionsCount = e
        }
        if let v = data.etfsInvestmentAmount, let e = InvestmentAmount(rawValue: v) {
            self.etfsInvestmentAmount = e
        }
        if let v = data.derivativesTransactionsCount, let e = DerivativesTransactionCount(rawValue: v) {
            self.derivativesTransactionsCount = e
        }
        if let v = data.derivativesInvestmentAmount, let e = DerivativesInvestmentAmount(rawValue: v) {
            self.derivativesInvestmentAmount = e
        }
        if let v = data.derivativesHoldingPeriod, let e = HoldingPeriod(rawValue: v) {
            self.derivativesHoldingPeriod = e
        }
        if let v = data.otherAssets { self.otherAssets = v }
    }

    private func restoreRiskAndReturnFromSavedData(_ data: SavedOnboardingData) {
        if let v = data.desiredReturn, let e = DesiredReturn(rawValue: v) { self.desiredReturn = e }
        if let v = data.leveragedProductsTotalLossRiskAcknowledged {
            self.leveragedProductsTotalLossRiskAcknowledged = v
        }
        if let v = data.leveragedProductsKnowledgeTestAnswers {
            self.leveragedProductsKnowledgeTestAnswers = v
        }
        self.restoreManualRiskClassOverride(from: data)
        self.syncOnboardingRiskClassSelection()
    }

    /// Restores only explicit manual upgrades (RC7 or above calculated), not conservative-gate RC1 snapshots.
    private func restoreManualRiskClassOverride(from data: SavedOnboardingData) {
        guard let finalRaw = data.finalRiskClass,
              let final = RiskClass(rawValue: finalRaw) else {
            return
        }

        if final == .riskClass7 {
            self.userSelectedRiskClass = .riskClass7
            return
        }

        guard let calculatedRaw = data.calculatedRiskClass,
              let calculated = RiskClass(rawValue: calculatedRaw),
              final.rawValue > calculated.rawValue else {
            return
        }

        self.userSelectedRiskClass = final
    }

    private func restoreDeclarationsFromSavedData(_ data: SavedOnboardingData) {
        if let v = data.insiderTradingOptions { self.insiderTradingOptions = v }
        if let v = data.moneyLaunderingDeclaration { self.moneyLaunderingDeclaration = v }
        if let v = data.assetType, let e = AssetType.fromOnboardingBackendKey(v) { self.assetType = e }
        if let v = data.leveragedProductsExperience { self.leveragedProductsExperience = v }
        if let v = data.financialProductsExperience { self.financialProductsExperience = v }
    }

    private func restoreTermsFromSavedData(_ data: SavedOnboardingData) {
        if let v = data.acceptedTerms { self.acceptedTerms = v }
        if let v = data.acceptedPrivacyPolicy { self.acceptedPrivacyPolicy = v }
        if let v = data.acceptedMarketingConsent { self.acceptedMarketingConsent = v }
    }

    private func restoreMetaFromSavedData(_ data: SavedOnboardingData) {
        if let v = data.customerNumber ?? data.customerId, !v.isEmpty { self.customerNumber = v }
    }

    // MARK: - Pre-fill with Test Data (DEBUG only)
    #if DEBUG
    /// Fills all text fields and toggles needed to click through the 22-step Get Started flow.
    func prefillTestData() {
        self.accountType = .individual
        self.userRole = .investor
        self.email = TestConstants.signupTestEmail()
        self.phoneNumber = TestConstants.signupTestPhone
        self.username = TestConstants.signupTestUsername()
        self.password = TestConstants.password
        self.confirmPassword = TestConstants.password

        self.salutation = .mr
        self.academicTitle = ""
        self.firstName = TestConstants.signupTestFirstName
        self.lastName = TestConstants.signupTestLastName
        self.streetAndNumber = TestConstants.signupTestStreet
        self.postalCode = TestConstants.signupTestPostalCode
        self.city = TestConstants.signupTestCity
        self.state = TestConstants.signupTestState
        self.country = TestConstants.signupTestCountry
        self.placeOfBirth = TestConstants.signupTestCity
        self.countryOfBirth = TestConstants.signupTestCountry
        self.dateOfBirth = Calendar.current.date(byAdding: .year, value: -35, to: Date()) ?? Date()

        self.isNotUSCitizen = true
        self.nationality = TestConstants.signupTestCountry
        self.additionalNationalities = ""
        self.address = "\(TestConstants.signupTestStreet), \(TestConstants.signupTestPostalCode) \(TestConstants.signupTestCity)"
        self.taxNumber = TestConstants.signupTestTaxNumber
        self.additionalResidenceCountry = ""
        self.additionalTaxNumber = ""
        self.showAdditionalFields = false

        self.identificationType = .passport
        self.identificationConfirmed = true

        self.addressConfirmed = true

        // Keep checkbox sections prefilled for fast DEBUG click-through; pickers stay unset (`---`).
        self.income = "75000"
        self.incomeSources = [
            "Settlement": false,
            "Inheritance": false,
            "Savings": false,
            "Financial contributions to family": false,
            "Salary": true,
            "Pension": false,
            "Assets": false,
            "Other (please specify)": false
        ]
        self.otherIncomeSource = ""
        self.otherAssets = [
            "Real estate": false,
            "Gold, silver": false,
            "No": true
        ]
        self.clearStep15And16PickerSelections()

        self.desiredReturn = .atLeastTenPercent

        self.insiderTradingOptions = [
            "Brokerage or Stock Exchange Employee": false,
            "Director or 10% Shareholder": false,
            "High-Ranking Official": false,
            "None of the above": true
        ]
        self.moneyLaunderingDeclaration = true
        self.assetType = .privateAssets
        self.leveragedProductsExperience = false
        self.financialProductsExperience = true

        // Legal Gate 1 (Contact): prefill both for fast DEBUG click-through.
        self.acceptedTerms = true
        self.acceptedPrivacyPolicy = true
        self.acceptedMarketingConsent = false

        self.generateCustomerNumber()
    }
    #endif
}
