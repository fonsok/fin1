import SwiftUI

// MARK: - Progressive Save & Resume

extension SignUpCoordinator {

    /// Saves step position and marks phase complete when crossing a phase boundary.
    /// Partial saves are debounced to reduce backend write volume under fast navigation.
    func persistStepTransition(from oldStep: SignUpStep, to newStep: SignUpStep) {
        resetInactivityTimer()

        if oldStep == .welcome {
            self.trackOnboardingStartedIfNeeded()
        }

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

        let exportedData = data.savedOnboardingData()
        let oldPhase = oldStep.phase
        let newPhase = newStep.phase
        let crossedPhase = newPhase.rawValue > oldPhase.rawValue
        let stepKey = newStep.backendKey
        let phaseStep = oldPhase.completionBackendStep

        self.onboardingPersistDebounceGeneration &+= 1
        let generation = self.onboardingPersistDebounceGeneration

        Task {
            if Self.onboardingPersistDebounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: Self.onboardingPersistDebounceNanoseconds)
            }
            guard generation == self.onboardingPersistDebounceGeneration else { return }

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
                try await onboardingAPI.savePartialProgressPositionOnly(step: stepKey)
            } catch {
                print("⚠️ Failed to save step position: \(error.localizedDescription)")
            }
        }
    }

    /// Fetches onboarding progress from backend, restores form data, and jumps to the saved step.
    func resumeOnboarding() async {
        guard let onboardingAPI = onboardingAPIService else { return }

        let stepAtResumeStart = self.currentStep
        self.isResuming = true
        defer { self.isResuming = false }

        do {
            let progress = try await onboardingAPI.getOnboardingProgress()

            if progress.onboardingCompleted {
                self.requestDismissal()
                return
            }

            let targetStep = progress.currentStep.flatMap { SignUpStep.fromBackendKey($0) }

            if let saved = progress.savedData {
                signUpData?.restoreFromSavedData(
                    saved,
                    resumeStep: targetStep,
                    lockAccountRole: userService?.isAuthenticated == true
                )
            }

            self.applyServerRoleToSignUpData()

            if let targetStep, self.currentStep == stepAtResumeStart {
                let stepsForRole = SignUpStep.stepsForRole(self.userRole)
                if let targetIndex = stepsForRole.firstIndex(of: targetStep),
                   let currentIndex = stepsForRole.firstIndex(of: stepAtResumeStart),
                   targetIndex > currentIndex {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.currentStep = targetStep
                    }
                }
            }

            if self.currentStep != .welcome {
                self.trackOnboardingStartedIfNeeded()
            }
        } catch {
            print("⚠️ Failed to resume onboarding: \(error.localizedDescription)")
        }
    }

    /// After account creation, `_User.role` is immutable — align UI/coordinator with server.
    func applyServerRoleToSignUpData() {
        guard let user = userService?.currentUser else { return }
        setUserRole(user.role)
        signUpData?.userRole = user.role
    }
}
