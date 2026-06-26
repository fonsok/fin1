import Foundation

extension UserService {

    /// Marks retail onboarding complete on the local user immediately after server `completeOnboardingStep(verification)`.
    /// `refreshUserData()` may follow to merge server fields; this prevents a blank dashboard shell if refresh lags.
    @MainActor
    func applyOnboardingCompletion(onboardingStep: String = "verification") {
        guard var user = self.currentUser else { return }
        user.onboardingCompleted = true
        user.onboardingStep = onboardingStep
        self.currentUser = user
        NotificationCenter.default.post(name: .userDataDidUpdate, object: nil)
    }

    @MainActor
    func applyRoleAgreementAcceptanceIfNeeded(role: UserRole, version: String?, accepted: Bool) {
        guard accepted, var user = self.currentUser else { return }
        let trimmedVersion = version?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedVersion = (trimmedVersion?.isEmpty == false) ? trimmedVersion : nil

        switch role {
        case .trader:
            user.acceptedTraderAgreement = true
            if user.acceptedTraderAgreementVersion == nil {
                user.acceptedTraderAgreementVersion = resolvedVersion
            }
            if user.acceptedTraderAgreementDate == nil {
                user.acceptedTraderAgreementDate = Date()
            }
        case .investor:
            user.acceptedInvestorAgreement = true
            if user.acceptedInvestorAgreementVersion == nil {
                user.acceptedInvestorAgreementVersion = resolvedVersion
            }
            if user.acceptedInvestorAgreementDate == nil {
                user.acceptedInvestorAgreementDate = Date()
            }
        default:
            return
        }

        self.currentUser = user
        NotificationCenter.default.post(name: .userDataDidUpdate, object: nil)
    }
}
