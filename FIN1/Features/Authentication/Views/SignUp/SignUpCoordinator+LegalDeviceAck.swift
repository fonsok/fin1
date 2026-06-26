import Foundation

extension SignUpCoordinator {

    /// Mirrors Legal Gate 1 (Contact / finalize) into the per-install device store so the
    /// post-registration modal does not re-prompt after signup on this device.
    func mirrorSignupLegalGateToDeviceStore(
        user: User,
        termsContentService: (any TermsContentServiceProtocol)?
    ) async {
        guard user.acceptedTerms, user.acceptedPrivacyPolicy else { return }

        let resolved = await LegalConsentVersionResolver.resolveDocuments(
            user: user,
            termsContentService: termsContentService
        )
        DeviceLegalConsentStore.markAcknowledgedForActiveDocuments(
            user: user,
            termsVersion: resolved.termsVersion,
            privacyVersion: resolved.privacyVersion
        )
    }
}
