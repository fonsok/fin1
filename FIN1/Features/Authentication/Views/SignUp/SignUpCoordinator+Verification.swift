import SwiftUI

// MARK: - Email & Phone Verification

extension SignUpCoordinator {

    func sendVerificationCode() {
        guard let onboardingAPI = onboardingAPIService else { return }

        Task {
            do {
                _ = try await onboardingAPI.sendVerificationCode()
                self.startResendCountdown()
            } catch {
                verificationError = error.localizedDescription
            }
        }
    }

    func verifyCode() {
        guard let onboardingAPI = onboardingAPIService else { return }
        let code = verificationCode
        guard code.count == 6 else { return }

        isVerifyingCode = true
        verificationError = nil

        Task {
            do {
                let result = try await onboardingAPI.verifyEmailCode(code)
                isVerifyingCode = false
                if result.verified {
                    // Route through coordinator flow logic to respect account-type specific paths.
                    nextStep()
                    self.stopResendTimer()
                }
            } catch {
                isVerifyingCode = false
                verificationCode = ""
                verificationError = error.localizedDescription
            }
        }
    }

    func resendCode() {
        verificationCode = ""
        verificationError = nil
        self.sendVerificationCode()
    }

    func startResendCountdown() {
        canResendCode = false
        resendCountdown = 60
        self.stopResendTimer()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.resendCountdown -= 1
                if self.resendCountdown <= 0 {
                    self.canResendCode = true
                    self.stopResendTimer()
                }
            }
        }
    }

    func stopResendTimer() {
        resendTimer?.invalidate()
        resendTimer = nil
    }

    func sendPhoneVerificationCode() {
        guard let onboardingAPI = onboardingAPIService,
              let phone = signUpData?.phoneNumber, !phone.isEmpty else { return }

        phoneVerificationError = nil
        phoneVerificationCode = ""

        Task {
            do {
                _ = try await onboardingAPI.sendPhoneVerificationCode(phoneNumber: phone)
                self.startPhoneResendCountdown()
            } catch {
                phoneVerificationError = error.localizedDescription
            }
        }
    }

    func verifyPhoneCode() {
        guard let onboardingAPI = onboardingAPIService else { return }
        let code = phoneVerificationCode.trimmingCharacters(in: .whitespaces)
        guard code.count == 6 else { return }

        isVerifyingPhone = true
        phoneVerificationError = nil

        Task {
            do {
                let result = try await onboardingAPI.verifyPhoneCode(code)
                isVerifyingPhone = false
                if result.verified {
                    // Route through coordinator flow logic to respect account-type specific paths.
                    nextStep()
                    self.stopPhoneResendTimer()
                }
            } catch {
                isVerifyingPhone = false
                phoneVerificationCode = ""
                phoneVerificationError = error.localizedDescription
            }
        }
    }

    func resendPhoneCode() {
        phoneVerificationCode = ""
        phoneVerificationError = nil
        self.sendPhoneVerificationCode()
    }

    func startPhoneResendCountdown() {
        canResendPhoneCode = false
        phoneResendCountdown = 60
        self.stopPhoneResendTimer()
        phoneResendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.phoneResendCountdown -= 1
                if self.phoneResendCountdown <= 0 {
                    self.canResendPhoneCode = true
                    self.stopPhoneResendTimer()
                }
            }
        }
    }

    func stopPhoneResendTimer() {
        phoneResendTimer?.invalidate()
        phoneResendTimer = nil
    }

    func resetToFirstStep() {
        currentStep = .welcome
        isLoading = false
        showAlert = false
        alertMessage = ""
    }
}
