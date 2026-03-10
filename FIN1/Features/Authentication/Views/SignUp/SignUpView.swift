import SwiftUI

// Import Navigation components
// Note: These components are now in the Navigation subfolder

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var appServices
    @StateObject private var coordinator = SignUpCoordinator()
    @StateObject private var signUpData: SignUpData
    @State private var showTermsOfService = false

    init() {
        // Create SignUpData with services - we'll inject them via environment in onAppear
        // For now create without services, they'll be injected later
        _signUpData = StateObject(wrappedValue: SignUpData())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AppTheme.screenBackground
                    .ignoresSafeArea()

                if coordinator.isResuming {
                    VStack(spacing: ResponsiveDesign.spacing(16)) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Resuming your progress…")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor)
                    }
                }

                VStack(spacing: ResponsiveDesign.spacing(0)) {
                    // Progress Bar
                    SignUpProgressBar(
                        progress: coordinator.progress,
                        currentStep: coordinator.currentStepNumber,
                        totalSteps: coordinator.totalStepsForRole,
                        phase: coordinator.currentStep.phase
                    )
                    .padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())

                    // Step Content
                    ScrollView {
                        VStack(spacing: ResponsiveDesign.spacing(24)) {
                            currentStepView
                        }
                        .padding(.top, ResponsiveDesign.spacing(8))
                        .padding(.bottom, ResponsiveDesign.spacing(8))
                        .padding(.horizontal, ResponsiveDesign.scrollSectionHorizontalPadding())
                        .background(AppTheme.systemSecondaryBackground)
                        .cornerRadius(ResponsiveDesign.spacing(12))
                    }
                    .padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())

                    // Navigation Buttons
                    SignUpNavigationButtons(
                        coordinator: coordinator,
                        signUpData: signUpData,
                        onComplete: completeRegistration,
                        onShowTermsOfService: { showTermsOfService = true }
                    )
                    .padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())
                }
                .opacity(coordinator.isResuming ? 0 : 1)
            }
            .navigationTitle(coordinator.isFirstStep ? "Konto eröffnen" : "Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(coordinator.isFirstStep ? "Abbrechen" : "Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
        .alert("Registration Error", isPresented: $coordinator.showAlert) {
            Button("OK") { }
        } message: {
            Text(coordinator.alertMessage)
        }
        .alert("Session Timeout", isPresented: $coordinator.showTimeoutWarning) {
            Button("Continue Session") {
                coordinator.extendSession()
            }
            Button("End Session", role: .destructive) {
                coordinator.stopInactivityTimers()
                coordinator.requestDismissal()
            }
        } message: {
            Text("Your session will expire in \(coordinator.timeoutCountdown) seconds due to inactivity. Sensitive data will be cleared for your security.")
        }
        .onAppear {
            coordinator.signUpData = signUpData
            signUpData.injectServices(
                riskClassCalculationService: appServices.riskClassCalculationService,
                investmentExperienceCalculationService: appServices.investmentExperienceCalculationService
            )
            coordinator.setValidation(
                DefaultStepValidation(testModeService: appServices.testModeService)
            )
            coordinator.configureServices(
                onboardingAPIService: appServices.onboardingAPIService,
                userService: appServices.userService,
                telemetryService: appServices.telemetryService
            )
            Task {
                await coordinator.resumeOnboarding()
                coordinator.startInactivityTimer()
            }
        }
        .onChange(of: signUpData.userRole) { _, newRole in
            coordinator.setUserRole(newRole)
        }
        .onChange(of: coordinator.currentStep) { _, newStep in
            if newStep == .emailVerification {
                coordinator.sendVerificationCode()
            } else if newStep == .phoneVerification {
                coordinator.sendPhoneVerificationCode()
            }
        }
        .onChange(of: coordinator.shouldDismiss) { _, newValue in
            if newValue {
                dismiss()
                coordinator.shouldDismiss = false
            }
        }
        .onDisappear {
            coordinator.stopInactivityTimers()
            coordinator.trackDropOffIfNeeded()
        }
        .fullScreenCover(isPresented: $coordinator.showWelcomePage) {
            WelcomePage(coordinator: coordinator)
        }
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView(
                configurationService: appServices.configurationService,
                termsContentService: appServices.termsContentService
            )
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch coordinator.currentStep {
        case .welcome:
            WelcomeStep(
                accountType: $signUpData.accountType,
                userRole: $signUpData.userRole
            )
        case .contact:
            ContactStep(
                email: $signUpData.email,
                phoneNumber: $signUpData.phoneNumber,
                username: $signUpData.username,
                password: $signUpData.password,
                confirmPassword: $signUpData.confirmPassword
            )
        case .accountCreated:
            AccountCreatedStep()
        case .emailVerification:
            EmailVerificationStep(
                email: signUpData.email,
                verificationCode: $coordinator.verificationCode,
                isVerifying: coordinator.isVerifyingCode,
                errorMessage: coordinator.verificationError,
                canResend: coordinator.canResendCode,
                resendCountdown: coordinator.resendCountdown,
                onVerify: coordinator.verifyCode,
                onResend: coordinator.resendCode
            )
        case .phoneVerification:
            PhoneVerificationStep(
                phoneNumber: signUpData.phoneNumber,
                verificationCode: $coordinator.phoneVerificationCode,
                isVerifying: coordinator.isVerifyingPhone,
                errorMessage: coordinator.phoneVerificationError,
                canResend: coordinator.canResendPhoneCode,
                resendCountdown: coordinator.phoneResendCountdown,
                onVerify: coordinator.verifyPhoneCode,
                onResend: coordinator.resendPhoneCode
            )
        case .personalInfo:
            PersonalInfoStep(
                salutation: $signUpData.salutation,
                academicTitle: $signUpData.academicTitle,
                firstName: $signUpData.firstName,
                lastName: $signUpData.lastName,
                streetAndNumber: $signUpData.streetAndNumber,
                postalCode: $signUpData.postalCode,
                city: $signUpData.city,
                state: $signUpData.state,
                country: $signUpData.country,
                dateOfBirth: $signUpData.dateOfBirth,
                placeOfBirth: $signUpData.placeOfBirth,
                countryOfBirth: $signUpData.countryOfBirth
            )
        case .citizenshipTax:
            CitizenshipTaxStep(
                isNotUSCitizen: $signUpData.isNotUSCitizen,
                nationality: $signUpData.nationality,
                taxNumber: $signUpData.taxNumber,
                additionalResidenceCountry: $signUpData.additionalResidenceCountry,
                additionalTaxNumber: $signUpData.additionalTaxNumber,
                address: $signUpData.address,
                showAdditionalFields: $signUpData.showAdditionalFields
            )
        case .identificationType:
            IdentificationTypeStep(identificationType: $signUpData.identificationType)
        case .identificationUploadFront:
            IdentificationUploadFrontStep(
                identificationType: signUpData.identificationType,
                passportFrontImage: $signUpData.passportFrontImage,
                idCardFrontImage: $signUpData.idCardFrontImage
            )
        case .identificationUploadBack:
            IdentificationUploadBackStep(
                identificationType: signUpData.identificationType,
                passportBackImage: $signUpData.passportBackImage,
                idCardBackImage: $signUpData.idCardBackImage
            )
        case .postidentConfirmation:
            PostidentConfirmationStep(
                identificationConfirmed: $signUpData.identificationConfirmed
            )
        case .identificationConfirm:
            IdentificationConfirmStep(
                identificationType: signUpData.identificationType,
                passportFrontImage: signUpData.passportFrontImage,
                passportBackImage: signUpData.passportBackImage,
                idCardFrontImage: signUpData.idCardFrontImage,
                idCardBackImage: signUpData.idCardBackImage,
                identificationConfirmed: $signUpData.identificationConfirmed
            )
        case .addressConfirm:
            AddressConfirmStep(
                addressConfirmed: $signUpData.addressConfirmed,
                addressVerificationDocument: $signUpData.addressVerificationDocument
            )
        case .addressConfirmSuccess:
            AddressConfirmSuccessStep()
        case .financial:
            FinancialStep(
                employmentStatus: $signUpData.employmentStatus,
                income: $signUpData.income,
                incomeRange: $signUpData.incomeRange,
                incomeSources: $signUpData.incomeSources,
                otherIncomeSource: $signUpData.otherIncomeSource,
                cashAndLiquidAssets: $signUpData.cashAndLiquidAssets
            )
        case .experience:
            ExperienceStep(
                stocksTransactionsCount: $signUpData.stocksTransactionsCount,
                stocksInvestmentAmount: $signUpData.stocksInvestmentAmount,
                etfsTransactionsCount: $signUpData.etfsTransactionsCount,
                etfsInvestmentAmount: $signUpData.etfsInvestmentAmount,
                derivativesTransactionsCount: $signUpData.derivativesTransactionsCount,
                derivativesInvestmentAmount: $signUpData.derivativesInvestmentAmount,
                derivativesHoldingPeriod: $signUpData.derivativesHoldingPeriod,
                otherAssets: $signUpData.otherAssets
            )
        case .desiredReturn:
            DesiredReturnStep(desiredReturn: $signUpData.desiredReturn)
        case .nonInsiderDeclaration:
            NonInsiderDeclarationStep(insiderTradingOptions: $signUpData.insiderTradingOptions)
        case .moneyLaunderingDeclaration:
            MoneyLaunderingDeclarationStep(
                moneyLaunderingDeclaration: $signUpData.moneyLaunderingDeclaration,
                assetType: $signUpData.assetType
            )
        case .terms:
            TermsStep(
                acceptedTerms: $signUpData.acceptedTerms,
                acceptedPrivacyPolicy: $signUpData.acceptedPrivacyPolicy,
                acceptedMarketingConsent: $signUpData.acceptedMarketingConsent
            )
        case .summary:
            SummaryStep(signUpData: signUpData, coordinator: coordinator)
        case .riskClassificationNote:
            RiskClassificationNoteStep(signUpData: signUpData, coordinator: coordinator)
        case .riskClass7Confirmation:
            RiskClass7ConfirmationStep(signUpData: signUpData, coordinator: coordinator)
        }
    }

    private func completeRegistration() {
        coordinator.isLoading = true

        Task {
            do {
                let user = try signUpData.createUser()
                let exportedData = signUpData.exportSignUpData()

                try await appServices.userService.updateProfile(user)

                if let onboardingAPI = appServices.onboardingAPIService {
                    // Mark legalConsent phase complete
                    _ = try await onboardingAPI.completeStep(
                        step: OnboardingPhase.legalConsent.completionBackendStep,
                        data: exportedData
                    )
                    // Mark the final verification step
                    _ = try await onboardingAPI.completeStep(
                        step: "verification",
                        data: exportedData
                    )
                }

                coordinator.trackOnboardingCompleted()
                coordinator.isLoading = false
                dismiss()
            } catch {
                coordinator.isLoading = false
                coordinator.showError(error.localizedDescription)
            }
        }
    }
}

#Preview {
    SignUpView()
}
