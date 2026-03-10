import SwiftUI

// MARK: - Progressive Save & Resume

extension SignUpCoordinator {

    /// Saves step position and marks phase complete when crossing a phase boundary.
    func persistStepTransition(from oldStep: SignUpStep, to newStep: SignUpStep) {
        resetInactivityTimer()

        let elapsed = sessionStartDate.map { Int(Date().timeIntervalSince($0)) }
        telemetryService?.trackEvent(name: "onboarding_step_completed", properties: [
            "from_step": oldStep.backendKey,
            "to_step": newStep.backendKey,
            "from_phase": oldStep.phase.title,
            "to_phase": newStep.phase.title,
            "step_number": newStep.stepNumberForRole(userRole),
            "total_steps": SignUpStep.totalStepsForRole(userRole),
            "role": userRole.rawValue,
            "session_seconds": elapsed ?? 0
        ])

        guard let onboardingAPI = onboardingAPIService,
              let data = signUpData else { return }

        let exportedData = data.exportSignUpData()
        let oldPhase = oldStep.phase
        let newPhase = newStep.phase
        let crossedPhase = newPhase.rawValue > oldPhase.rawValue
        let stepKey = newStep.backendKey
        let phaseStep = oldPhase.completionBackendStep

        Task {
            do {
                try await onboardingAPI.savePartialProgress(
                    step: stepKey,
                    data: exportedData
                )
                if crossedPhase {
                    _ = try await onboardingAPI.completeStep(
                        step: phaseStep,
                        data: exportedData
                    )
                }
            } catch {
                print("⚠️ Failed to persist onboarding progress: \(error.localizedDescription)")
            }
        }
    }

    /// Lightweight position-only save (used when going back).
    func persistStepPosition(_ step: SignUpStep) {
        guard let onboardingAPI = onboardingAPIService else { return }
        let stepKey = step.backendKey

        Task {
            do {
                try await onboardingAPI.savePartialProgress(
                    step: stepKey,
                    data: ["_positionOnly": true]
                )
            } catch {
                print("⚠️ Failed to save step position: \(error.localizedDescription)")
            }
        }
    }

    /// Fetches onboarding progress from backend, restores form data, and jumps to the saved step.
    func resumeOnboarding() async {
        guard let onboardingAPI = onboardingAPIService else { return }

        if let user = userService?.currentUser {
            userRole = user.role
        }

        isResuming = true
        defer { isResuming = false }

        do {
            let progress = try await onboardingAPI.getOnboardingProgress()

            if progress.onboardingCompleted {
                requestDismissal()
                return
            }

            if let saved = progress.savedData {
                signUpData?.restoreFromSavedData(saved)
            }

            if let stepKey = progress.currentStep,
               let targetStep = SignUpStep.fromBackendKey(stepKey) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = targetStep
                }
            }
        } catch {
            print("⚠️ Failed to resume onboarding: \(error.localizedDescription)")
        }
    }
}
