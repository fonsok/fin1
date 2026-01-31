import SwiftUI

final class SignUpCoordinator: ObservableObject {
    @Published var currentStep: SignUpStep = .welcome
    @Published var isLoading: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var shouldDismiss = false // New property to signal dismissal

    private var validation: StepValidation
    // Changed from private to internal to allow access from extensions
    var userRole: UserRole = .investor // Default role
    weak var signUpData: SignUpData?

    init(validation: StepValidation? = nil) {
        self.validation = validation ?? DefaultStepValidation()
    }

    func setValidation(_ validation: StepValidation) {
        self.validation = validation
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
        withAnimation(.easeInOut(duration: 0.3)) {
            if let data = signUpData {
                // Use custom logic that handles Postident flow
                customNextStep(with: data)
            } else {
                // Fallback to default behavior
                if let nextStep = StepConfiguration.nextStep(after: currentStep, role: userRole) {
                    currentStep = nextStep
                }
            }
        }
    }

    func previousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let previousStep = StepConfiguration.previousStep(before: currentStep, role: userRole) {
                currentStep = previousStep
            }
        }
    }

    func goToStep(_ step: SignUpStep) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = step
        }
    }

    func goToStepNumber(_ stepNumber: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let step = StepConfiguration.step(for: stepNumber, role: userRole) {
                currentStep = step
            }
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

    func resetToFirstStep() {
        currentStep = .welcome
        isLoading = false
        showAlert = false
        alertMessage = ""
    }

    // MARK: - Welcome Page Navigation

    @Published var showWelcomePage = false

    func presentWelcomePage() {
        showWelcomePage = true
    }

    /// Check if user can proceed to next step based on validation
    func canProceedToNextStep(with data: SignUpData) -> Bool {
        validation.canProceedToNextStep(for: currentStep, with: data)
    }

    /// Get validation message for current step
    func getValidationMessage(with data: SignUpData) -> String? {
        validation.getValidationMessage(for: currentStep, with: data)
    }

    /// Get current step number (1-based) for current role
    var currentStepNumber: Int {
        currentStep.stepNumberForRole(userRole)
    }

    /// Get step number string (e.g., "1 of 17")
    var stepNumberString: String {
        StepConfiguration.stepNumberString(for: currentStep, role: userRole)
    }

    /// Get current step title
    var currentStepTitle: String {
        switch currentStep {
        case .welcome: return "Welcome"
        case .contact: return "Contact Information"
        case .accountCreated: return "Account Created"
        case .personalInfo: return "Personal Information"
        case .citizenshipTax: return "Citizenship & Tax"
        case .identificationType: return "Identification Type"
        case .identificationUploadFront: return "Upload ID Front"
        case .identificationUploadBack: return "Upload ID Back"
        case .postidentConfirmation: return "Postident"
        case .identificationConfirm: return "ID Confirmation"
        case .addressConfirm: return "Address Confirmation"
        case .addressConfirmSuccess: return "Address Success"
        case .financial: return "Financial Information"
        case .experience: return "Investment Experience"
        case .desiredReturn: return "Desired Return"
        case .nonInsiderDeclaration: return "Non-Insider Declaration"
        case .moneyLaunderingDeclaration: return "Money Laundering Declaration"
        case .terms: return "Terms & Conditions"
        case .summary: return "Summary"
        case .riskClassificationNote: return "Note on risk classification"
        case .riskClass7Confirmation: return "Risk Class 7 Confirmation"
        }
    }

    /// Get current step description
    var currentStepDescription: String {
        switch currentStep {
        case .welcome: return "Choose your account type"
        case .contact: return "Enter your contact details"
        case .accountCreated: return "Account successfully created"
        case .personalInfo: return "Provide personal information"
        case .citizenshipTax: return "Citizenship and tax details"
        case .identificationType: return "Select ID document type"
        case .identificationUploadFront: return "Upload front of ID"
        case .identificationUploadBack: return "Upload back of ID"
        case .postidentConfirmation: return "Postident verification"
        case .identificationConfirm: return "Confirm ID documents"
        case .addressConfirm: return "Confirm your address"
        case .addressConfirmSuccess: return "Address confirmed"
        case .financial: return "Financial background"
        case .experience: return "Investment experience"
        case .desiredReturn: return "Return expectations"
        case .nonInsiderDeclaration: return "Legal declarations"
        case .moneyLaunderingDeclaration: return "AML compliance"
        case .terms: return "Terms and conditions"
        case .summary: return "Review all information"
        case .riskClassificationNote: return "Risk classification information"
        case .riskClass7Confirmation: return "Confirm high-risk selection"
        }
    }

    /// Get current step icon
    var currentStepIcon: String {
        switch currentStep {
        case .welcome: return "person.badge.plus"
        case .contact: return "envelope"
        case .accountCreated: return "checkmark.circle"
        case .personalInfo: return "person.text.rectangle"
        case .citizenshipTax: return "flag"
        case .identificationType: return "doc.text"
        case .identificationUploadFront: return "camera"
        case .identificationUploadBack: return "camera.fill"
        case .postidentConfirmation: return "building.columns"
        case .identificationConfirm: return "checkmark.shield"
        case .addressConfirm: return "house"
        case .addressConfirmSuccess: return "checkmark.house"
        case .financial: return "chart.bar"
        case .experience: return "chart.line.uptrend.xyaxis"
        case .desiredReturn: return "percent"
        case .nonInsiderDeclaration: return "hand.raised"
        case .moneyLaunderingDeclaration: return "shield"
        case .terms: return "doc.text"
        case .summary: return "list.bullet"
        case .riskClassificationNote: return "exclamationmark.triangle"
        case .riskClass7Confirmation: return "exclamationmark.triangle.fill"
        }
    }
}
