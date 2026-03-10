import SwiftUI

@MainActor
final class SignUpCoordinator: ObservableObject {
    @Published var currentStep: SignUpStep = .welcome
    @Published var isLoading: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var shouldDismiss = false // New property to signal dismissal

    var validation: StepValidation
    // Changed from private to internal to allow access from extensions
    var userRole: UserRole = .investor // Default role
    weak var signUpData: SignUpData?

    // Backend integration for early account creation and step persistence (internal for extensions)
    var onboardingAPIService: OnboardingAPIServiceProtocol?
    var userService: (any UserServiceProtocol)?
    var telemetryService: TelemetryServiceProtocol?
    var sessionStartDate: Date?
    @Published var accountCreationError: String?
    @Published var isResuming: Bool = false

    // Email verification state
    @Published var verificationCode: String = ""
    @Published var isVerifyingCode: Bool = false
    @Published var verificationError: String?
    @Published var canResendCode: Bool = false
    @Published var resendCountdown: Int = 60
    var resendTimer: Timer?

    // Phone verification state
    @Published var phoneVerificationCode: String = ""
    @Published var isVerifyingPhone: Bool = false
    @Published var phoneVerificationError: String?
    @Published var canResendPhoneCode: Bool = false
    @Published var phoneResendCountdown: Int = 60
    var phoneResendTimer: Timer?

    // Session timeout (BaFin: sensitive data must not linger in memory)
    @Published var showTimeoutWarning: Bool = false
    @Published var timeoutCountdown: Int = 60
    static let inactivityTimeout: TimeInterval = 10 * 60 // 10 min
    static let warningLeadTime: TimeInterval = 60        // warn 60s before
    var inactivityTimer: Timer?
    var warningTimer: Timer?
    var countdownTimer: Timer?

    init(validation: StepValidation? = nil) {
        self.validation = validation ?? DefaultStepValidation()
    }

    func setValidation(_ validation: StepValidation) {
        self.validation = validation
    }

    func configureServices(
        onboardingAPIService: OnboardingAPIServiceProtocol?,
        userService: any UserServiceProtocol,
        telemetryService: TelemetryServiceProtocol? = nil
    ) {
        self.onboardingAPIService = onboardingAPIService
        self.userService = userService
        self.telemetryService = telemetryService
        self.sessionStartDate = Date()
        telemetryService?.trackEvent(name: "onboarding_started", properties: [
            "role": userRole.rawValue
        ])
    }

    /// Set the user role (should be called after user selects role in welcome step)
    func setUserRole(_ role: UserRole) {
        userRole = role
    }

    /// Total steps (automatically calculated from enum)
    static var totalSteps: Int {
        StepConfiguration.totalSteps
    }

    /// Total steps for current user role
    var totalStepsForRole: Int {
        StepConfiguration.totalSteps(for: userRole)
    }

    var progress: Double {
        StepConfiguration.progressPercentage(for: currentStep, role: userRole)
    }

    var canGoBack: Bool {
        !StepConfiguration.isFirstStep(currentStep, role: userRole)
    }

    var canGoForward: Bool {
        !StepConfiguration.isLastStep(currentStep, role: userRole)
    }

    var isFirstStep: Bool {
        StepConfiguration.isFirstStep(currentStep, role: userRole)
    }

    var isLastStep: Bool {
        StepConfiguration.isLastStep(currentStep, role: userRole)
    }

    func nextStep() {
        let oldStep = currentStep
        withAnimation(.easeInOut(duration: 0.3)) {
            if let data = signUpData {
                customNextStep(with: data)
            } else {
                if let nextStep = StepConfiguration.nextStep(after: currentStep, role: userRole) {
                    currentStep = nextStep
                }
            }
        }
        if currentStep != oldStep {
            persistStepTransition(from: oldStep, to: currentStep)
        }
    }

    func previousStep() {
        let oldStep = currentStep
        withAnimation(.easeInOut(duration: 0.3)) {
            if let previousStep = StepConfiguration.previousStep(before: currentStep, role: userRole) {
                currentStep = previousStep
            }
        }
        if currentStep != oldStep {
            persistStepPosition(currentStep)
        }
    }

    func goToStep(_ step: SignUpStep) {
        let oldStep = currentStep
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = step
        }
        if currentStep != oldStep {
            persistStepTransition(from: oldStep, to: step)
        }
    }

    func goToStepNumber(_ stepNumber: Int) {
        let oldStep = currentStep
        withAnimation(.easeInOut(duration: 0.3)) {
            if let step = StepConfiguration.step(for: stepNumber, role: userRole) {
                currentStep = step
            }
        }
        if currentStep != oldStep {
            persistStepTransition(from: oldStep, to: currentStep)
        }
    }

    func showError(_ message: String) {
        alertMessage = message
        showAlert = true
    }

    func reset() {
        currentStep = .welcome
        isLoading = false
        showAlert = false
        alertMessage = ""
    }

    func requestDismissal() {
        shouldDismiss = true
    }

    // MARK: - Early Account Creation (after Contact step)

    /// Creates the account on the backend after Contact step,
    /// enabling session-based persistence for all subsequent steps.
    func createAccountIfNeeded(with data: SignUpData) async {
        guard currentStep == .contact else { return }
        guard let userService = userService else {
            advanceFromContact()
            return
        }

        isLoading = true
        accountCreationError = nil

        do {
            try await userService.signUp(userData: User(
                id: UUID().uuidString,
                customerId: data.customerId,
                accountType: data.accountType,
                email: data.email,
                username: data.username,
                phoneNumber: data.phoneNumber,
                password: data.password,
                salutation: data.salutation,
                academicTitle: "",
                firstName: "",
                lastName: "",
                streetAndNumber: "",
                postalCode: "",
                city: "",
                state: "",
                country: "Deutschland",
                dateOfBirth: Date(),
                placeOfBirth: "",
                countryOfBirth: "Deutschland",
                role: data.userRole,
                employmentStatus: .employed,
                income: 0,
                incomeRange: .low,
                riskTolerance: 0,
                address: "",
                nationality: "",
                additionalNationalities: "",
                taxNumber: "",
                additionalTaxResidences: "",
                isNotUSCitizen: true,
                identificationType: .passport,
                passportFrontImageURL: nil,
                passportBackImageURL: nil,
                idCardFrontImageURL: nil,
                idCardBackImageURL: nil,
                identificationConfirmed: false,
                addressConfirmed: false,
                addressVerificationDocumentURL: nil,
                leveragedProductsExperience: false,
                financialProductsExperience: false,
                investmentExperience: 0,
                tradingFrequency: 0,
                investmentKnowledge: 0,
                desiredReturn: .atLeastTenPercent,
                insiderTradingOptions: [:],
                moneyLaunderingDeclaration: false,
                assetType: .privateAssets,
                profileImageURL: nil,
                isEmailVerified: false,
                isKYCCompleted: false,
                acceptedTerms: false,
                acceptedPrivacyPolicy: false,
                acceptedMarketingConsent: false,
                lastLoginDate: nil,
                createdAt: Date(),
                updatedAt: Date()
            ))

            isLoading = false
            advanceFromContact()
        } catch {
            isLoading = false
            accountCreationError = error.localizedDescription
            showError("Account creation failed: \(error.localizedDescription)")
        }
    }

    private func advanceFromContact() {
        let oldStep = currentStep
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = .accountCreated
        }
        persistStepTransition(from: oldStep, to: .accountCreated)
    }

    @Published var showWelcomePage = false
}
