import SwiftUI

// MARK: - Session Inactivity Timeout (BaFin: sensitive data must not linger)

extension SignUpCoordinator {

    func startInactivityTimer() {
        resetInactivityTimer()
    }

    /// Resets the inactivity countdown. Call on every user interaction / step change.
    func resetInactivityTimer() {
        stopInactivityTimers()
        showTimeoutWarning = false

        let warningDelay = Self.inactivityTimeout - Self.warningLeadTime

        inactivityTimer = Timer.scheduledTimer(withTimeInterval: Self.inactivityTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleSessionTimeout()
            }
        }

        warningTimer = Timer.scheduledTimer(withTimeInterval: warningDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.showTimeoutWarning else { return }
                self.showTimeoutWarning = true
                self.timeoutCountdown = Int(Self.warningLeadTime)
                self.countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                    Task { @MainActor in
                        guard let self else { return }
                        self.timeoutCountdown -= 1
                        if self.timeoutCountdown <= 0 {
                            self.countdownTimer?.invalidate()
                            self.countdownTimer = nil
                        }
                    }
                }
            }
        }
    }

    /// User tapped "Continue" on the timeout warning — reset the timer.
    func extendSession() {
        resetInactivityTimer()
    }

    func handleSessionTimeout() {
        stopInactivityTimers()

        telemetryService?.trackEvent(name: "onboarding_session_timeout", properties: [
            "last_step": currentStep.backendKey,
            "last_phase": currentStep.phase.title,
            "role": userRole.rawValue,
            "session_seconds": sessionStartDate.map { Int(Date().timeIntervalSince($0)) } ?? 0
        ])

        clearSensitiveData()
        requestDismissal()
    }

    func clearSensitiveData() {
        guard let data = signUpData else { return }
        data.password = ""
        data.confirmPassword = ""
        data.taxNumber = ""
        data.additionalTaxNumber = ""
        data.passportFrontImage = nil
        data.passportBackImage = nil
        data.idCardFrontImage = nil
        data.idCardBackImage = nil
    }

    func stopInactivityTimers() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        warningTimer?.invalidate()
        warningTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        showTimeoutWarning = false
    }
}
