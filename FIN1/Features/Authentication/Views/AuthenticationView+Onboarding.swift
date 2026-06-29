import SwiftUI

extension AuthenticationView {

    func checkOnboardingStatus() {
        guard let user = self.session.currentUser else {
            self.isSignUpPresented = false
            SignUpFlowSession.end()
            self.showCompanyKybResume = false
            self.showCompanyKybStatus = false
            return
        }

        if user.onboardingCompleted {
            self.isSignUpPresented = false
            SignUpFlowSession.end()
        }

        // Company accounts: KYB takes precedence over personal onboarding
        if user.accountType == .company {
            let kybStatus = user.companyKybStatus

            // Post-reset: status is 'draft' and completed is false -- re-enter wizard
            if kybStatus == "draft" && !user.companyKybCompleted {
                self.showCompanyKybResume = true
                self.showCompanyKybStatus = false
                return
            }

            if user.companyKybCompleted {
                if let status = CompanyKybReviewStatus(from: kybStatus), status != .approved {
                    self.companyKybReviewStatus = status
                    self.showCompanyKybStatus = true
                } else {
                    self.showCompanyKybStatus = false
                }
                self.showCompanyKybResume = false
                return
            }

            if user.companyKybStep != nil {
                self.showCompanyKybResume = true
                self.showCompanyKybStatus = false
                return
            }
        }

        self.showCompanyKybResume = false
        self.showCompanyKybStatus = false

        guard !user.onboardingCompleted, user.onboardingStep != nil else {
            return
        }

        if SignUpFlowSession.isPresentingFromLanding {
            return
        }

        if SignUpFlowSession.userLeftOnboarding {
            return
        }

        guard !self.isSignUpPresented else { return }

        self.isSignUpPresented = true
    }

    /// Re-open onboarding only after an unintentional cover dismiss (debounced).
    func scheduleOnboardingResumeIfNeededAfterDismiss() {
        self.onboardingRePresentTask?.cancel()
        self.onboardingRePresentTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            guard !SignUpFlowSession.userLeftOnboarding else { return }
            guard !self.isSignUpPresented else { return }
            self.checkOnboardingStatus()
        }
    }
}
