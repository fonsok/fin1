import Foundation

extension SignUpCoordinator {

    /// Persists the full onboarding profile (including final risk class) and marks onboarding complete on the server.
    @MainActor
    func finalizeRegistration(
        signUpData: SignUpData,
        appServices: AppServices
    ) async throws {
        guard signUpData.hasRequiredLegalConsents else {
            throw UserCreationError.legalConsentsIncomplete
        }

        if signUpData.userRole == .trader || signUpData.userRole == .investor {
            guard signUpData.hasRequiredRoleAgreement else {
                throw UserCreationError.roleAgreementIncomplete
            }
        }

        guard let sessionUser = appServices.userService.currentUser else {
            throw AppError.serviceError(.dataNotFound)
        }

        let user = try signUpData.mergedUserForFinalRegistration(base: sessionUser)
        let exportedData = signUpData.savedOnboardingData()
        let resolvedRiskTolerance = signUpData.finalRiskClass.rawValue

        try await appServices.userService.updateProfile(user)

        if let onboardingAPI = appServices.onboardingAPIService {
            // `risk` is already completed at the investmentReadiness → legalConsent phase boundary.
            _ = try await onboardingAPI.completeStep(
                step: OnboardingPhase.legalConsent.completionBackendStep,
                data: exportedData
            )
            _ = try await onboardingAPI.completeStep(
                step: "verification",
                data: exportedData
            )
        }

        await appServices.userService.applyRoleAgreementAcceptanceIfNeeded(
            role: signUpData.userRole,
            version: signUpData.userRole == .trader
                ? signUpData.acceptedTraderAgreementVersion
                : signUpData.acceptedInvestorAgreementVersion,
            accepted: signUpData.hasRequiredRoleAgreement
        )
        try await appServices.userService.refreshUserData()
        await appServices.userService.applyRoleAgreementAcceptanceIfNeeded(
            role: signUpData.userRole,
            version: signUpData.userRole == .trader
                ? signUpData.acceptedTraderAgreementVersion
                : signUpData.acceptedInvestorAgreementVersion,
            accepted: signUpData.hasRequiredRoleAgreement
        )
        await appServices.userService.applyOnboardingCompletion(onboardingStep: "verification")
        await appServices.userService.applyRiskTolerance(resolvedRiskTolerance)

        if let refreshedUser = appServices.userService.currentUser {
            await self.mirrorSignupLegalGateToDeviceStore(
                user: refreshedUser,
                termsContentService: appServices.termsContentService
            )
        }

        self.trackOnboardingCompleted()
        self.registrationFinalizedSuccessfully = true

        NotificationCenter.default.post(name: .registrationDidFinalize, object: nil)
        NotificationCenter.default.post(name: .userDataDidUpdate, object: nil)
    }
}
