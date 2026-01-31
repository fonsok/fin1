import SwiftUI

// Extension to handle Postident flow logic
extension SignUpCoordinator {
    
    /// Determine the next step based on identification type
    func nextStepAfterIdentificationType(with data: SignUpData) -> SignUpStep {
        switch data.identificationType {
        case .passport, .idCard:
            // Regular flow for passport or ID card
            return .identificationUploadFront
        case .postident:
            // Skip to Postident confirmation step
            return .postidentConfirmation
        }
    }
    
    /// Determine the next step after document upload steps
    func nextStepAfterDocumentUpload(currentStep: SignUpStep, with data: SignUpData) -> SignUpStep? {
        switch currentStep {
        case .identificationUploadBack:
            // After uploading back of document, go to confirmation
            return .identificationConfirm
        case .postidentConfirmation:
            // After Postident confirmation, skip the regular ID confirmation and go to address
            return .addressConfirm
        default:
            // Use default next step logic for other cases
            return StepConfiguration.nextStep(after: currentStep, role: userRole)
        }
    }
    
    /// Override the default next step behavior to handle custom flows
    func customNextStep(with data: SignUpData) {
        // Handle special cases for identification flow
        if currentStep == .identificationType {
            currentStep = nextStepAfterIdentificationType(with: data)
        } else if currentStep == .identificationUploadBack || currentStep == .postidentConfirmation {
            if let nextStep = nextStepAfterDocumentUpload(currentStep: currentStep, with: data) {
                currentStep = nextStep
            }
        } else {
            // Default behavior
            if let nextStep = StepConfiguration.nextStep(after: currentStep, role: userRole) {
                currentStep = nextStep
            }
        }
    }
}
