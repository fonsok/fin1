import SwiftUI

extension AuthenticationView {

    func makeReConsentViewModel() -> ReConsentViewModel {
        ReConsentViewModel(
            userService: self.services.userService,
            termsAcceptanceService: self.services.termsAcceptanceService,
            roleAgreementConsentService: RoleAgreementConsentService(
                parseAPIClient: self.services.parseAPIClient
            ),
            parseAPIClient: self.services.parseAPIClient
        )
    }

    func beginLegalConsentGateCheck() {
        self.isResolvingLegalConsentGate = true
        Task {
            await self.evaluateLegalConsentRequirement(showOnlyIfNeeded: false)
        }
        Task {
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            await MainActor.run {
                guard self.isResolvingLegalConsentGate else { return }
                #if DEBUG
                print("⚠️ AuthenticationView: legal consent gate timed out — showing main content")
                #endif
                self.isResolvingLegalConsentGate = false
            }
        }
    }

    /// Show blocking modal when consent is still required; never hide on partial acceptance.
    func showTermsAcceptanceModalIfStillRequired() {
        Task {
            await self.evaluateLegalConsentRequirement(showOnlyIfNeeded: true)
            await self.evaluateReConsentRequirement(showOnlyIfNeeded: true)
        }
    }

    func evaluateLegalConsentRequirement(showOnlyIfNeeded: Bool) async {
        guard let user = services.userService.currentUser else {
            await MainActor.run {
                self.isResolvingLegalConsentGate = false
            }
            return
        }

        // Server sync only on full gate checks (login / completion). Partial accepts must not
        // import onboarding LegalConsent rows into the device store via userDataDidUpdate.
        if !showOnlyIfNeeded, let parseAPIClient = services.parseAPIClient {
            await DeviceLegalConsentStore.syncAcknowledgementsFromServer(
                user: user,
                parseAPIClient: parseAPIClient
            )
        }

        let termsVersion = await LegalConsentVersionResolver.resolveVersion(
            user: user,
            documentType: .terms,
            termsContentService: self.services.termsContentService
        )
        let privacyVersion = await LegalConsentVersionResolver.resolveVersion(
            user: user,
            documentType: .privacy,
            termsContentService: self.services.termsContentService
        )

        let needsTerms = self.services.termsAcceptanceService.needsToAcceptTerms(
            user: user,
            currentServerVersion: termsVersion
        )
        let needsPrivacy = self.services.termsAcceptanceService.needsToAcceptPrivacyPolicy(
            user: user,
            currentServerVersion: privacyVersion
        )
        if needsTerms || needsPrivacy {
            await MainActor.run {
                self.showTermsAcceptance = true
                self.showReConsent = false
                self.isResolvingLegalConsentGate = false
            }
            return
        }

        await MainActor.run {
            self.showTermsAcceptance = false
        }

        await self.evaluateReConsentRequirement(showOnlyIfNeeded: showOnlyIfNeeded)
    }

    func evaluateReConsentRequirement(showOnlyIfNeeded: Bool) async {
        guard self.services.userService.currentUser != nil else {
            await MainActor.run {
                self.showReConsent = false
                self.isResolvingLegalConsentGate = false
            }
            return
        }

        if !showOnlyIfNeeded {
            try? await self.services.userService.refreshUserData()
        }

        let blocking = self.services.userService.currentUser?.requiredReConsents?.filter(\.blocking) ?? []
        await MainActor.run {
            self.showReConsent = !blocking.isEmpty
            if blocking.isEmpty {
                self.reConsentViewModel = nil
            } else if self.reConsentViewModel == nil {
                self.reConsentViewModel = self.makeReConsentViewModel()
            } else {
                self.reConsentViewModel?.loadFromCurrentUser()
            }
            self.isResolvingLegalConsentGate = false
        }
    }
}
