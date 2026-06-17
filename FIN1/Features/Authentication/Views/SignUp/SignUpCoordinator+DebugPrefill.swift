import SwiftUI

#if DEBUG
extension SignUpCoordinator {

    /// Prefills sign-up form fields and enables test mode for document upload steps.
    /// Skips when the user already has contact data (resume flow), unless `force` is true.
    func applyDebugTestPrefillIfNeeded(
        to data: SignUpData,
        testModeService: any TestModeServiceProtocol,
        force: Bool = false
    ) {
        guard force || data.email.isEmpty else { return }

        data.prefillTestData()
        self.setUserRole(data.userRole)
        testModeService.enableTestMode()

        guard let testMode = testModeService as? TestModeService else { return }

        data.passportFrontImage = testMode.samplePassportImage
        data.passportBackImage = testMode.samplePassportImage
        data.idCardFrontImage = testMode.sampleIDCardImage
        data.idCardBackImage = testMode.sampleIDCardImage
        data.addressVerificationDocument = testMode.sampleAddressDocument
        data.identificationConfirmed = true
        data.addressConfirmed = true
    }

    /// Called when entering email or phone verification — prefills dev OTP and auto-submits.
    func handleDebugVerificationStepEntered(_ step: SignUpStep) {
        switch step {
        case .emailVerification:
            self.verificationError = nil
            self.verificationCode = TestConstants.devVerificationCode
            self.sendVerificationCode()
            self.scheduleDebugVerificationSubmit(for: .emailVerification)
        case .phoneVerification:
            self.phoneVerificationError = nil
            self.phoneVerificationCode = TestConstants.devVerificationCode
            self.sendPhoneVerificationCode(resetInput: false)
            self.scheduleDebugVerificationSubmit(for: .phoneVerification)
        default:
            break
        }
    }

    private func scheduleDebugVerificationSubmit(for step: SignUpStep) {
        Task {
            // Brief delay so Parse session from sign-up is visible to cloud functions.
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard self.currentStep == step else { return }
            switch step {
            case .emailVerification:
                self.verifyCode()
            case .phoneVerification:
                self.verifyPhoneCode()
            default:
                break
            }
        }
    }
}
#endif
