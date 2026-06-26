import SwiftUI

// MARK: - Telemetry (onboarding completed / drop-off)

extension SignUpCoordinator {

    /// Call when the user completes onboarding successfully.
    func trackOnboardingCompleted() {
        let elapsed = sessionStartDate.map { Int(Date().timeIntervalSince($0)) }
        telemetryService?.trackEvent(name: "onboarding_completed", properties: [
            "role": userRole.rawValue,
            "total_session_seconds": elapsed ?? 0
        ])
    }

    /// Call when the signup view disappears without the user having completed onboarding.
    func trackDropOffIfNeeded() {
        guard !self.registrationFinalizedSuccessfully else { return }
        guard self.currentStep != .welcome else { return }
        let completionStep = SignUpStep.registrationCompletionStep(for: self.userRole)
        let isComplete = self.currentStep == completionStep && self.shouldDismiss
        guard !isComplete else { return }
        let elapsed = sessionStartDate.map { Int(Date().timeIntervalSince($0)) }
        telemetryService?.trackEvent(name: "onboarding_drop_off", properties: [
            "last_step": currentStep.backendKey,
            "last_phase": currentStep.phase.title,
            "step_number": currentStep.stepNumberForRole(userRole),
            "total_steps": SignUpStep.totalStepsForRole(userRole),
            "role": userRole.rawValue,
            "session_seconds": elapsed ?? 0
        ])
    }
}
