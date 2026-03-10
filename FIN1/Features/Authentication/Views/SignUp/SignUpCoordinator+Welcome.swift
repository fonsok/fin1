import SwiftUI

// MARK: - Welcome Page & Validation

extension SignUpCoordinator {

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
}
