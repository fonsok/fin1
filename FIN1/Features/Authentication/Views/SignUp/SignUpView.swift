import SwiftUI

// Import Navigation components
// Note: These components are now in the Navigation subfolder

struct SignUpView: View {
    private static let scrollTopAnchorID = "SignUpScrollTop"

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

                if self.coordinator.isResuming {
                    VStack(spacing: ResponsiveDesign.spacing(16)) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Resuming your progress…")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor)
                    }
                }

                VStack(spacing: ResponsiveDesign.spacing(0)) {
                    SignUpProgressBar(
                        progress: self.coordinator.progress,
                        currentStep: self.coordinator.currentStepNumber,
                        totalSteps: self.coordinator.totalStepsForRole,
                        phase: self.coordinator.currentStep.phase
                    )
                    .padding(.horizontal, ResponsiveDesign.mainHorizontalPadding())
                    .padding(.top, ResponsiveDesign.spacing(8))
                    .padding(.bottom, ResponsiveDesign.spacing(12))

                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            VStack(spacing: ResponsiveDesign.spacing(0)) {
                                Color.clear
                                    .frame(height: 0)
                                    .id(SignUpView.scrollTopAnchorID)

                                self.currentStepView
                            }
                            .padding(.bottom, ResponsiveDesign.spacing(16))
                        }
                        .scrollDisabled(self.coordinator.currentStep == .roleAgreement)
                        .scrollIndicators(.hidden)
                        .onChange(of: self.coordinator.currentStep) { _, _ in
                            scrollProxy.scrollTo(SignUpView.scrollTopAnchorID, anchor: .top)
                        }
                    }

                    self.signUpFooter
                }
                .opacity(self.coordinator.isResuming ? 0 : 1)
            }
            .navigationTitle(self.coordinator.isFirstStep ? "Konto eröffnen" : "Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if self.coordinator.canGoBack {
                        Button {
                            self.coordinator.previousStep()
                        } label: {
                            HStack(spacing: ResponsiveDesign.spacing(4)) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                        .foregroundColor(AppTheme.accentLightBlue)
                        .accessibilityIdentifier("SignUpBackButton")
                    } else {
                        Button("Abbrechen") {
                            SignUpFlowSession.markUserLeftOnboarding()
                            SignUpFlowSession.end()
                            self.dismiss()
                        }
                        .foregroundColor(AppTheme.accentLightBlue)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if self.coordinator.canGoBack {
                        Button("Cancel") {
                            self.coordinator.requestReturnToLanding()
                        }
                        .foregroundColor(AppTheme.accentLightBlue)
                    }
                }
                #if DEBUG
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Test Data") {
                        self.applyDebugTestPrefill(force: true)
                    }
                    .font(.caption)
                    .foregroundColor(AppTheme.accentLightBlue)
                    .accessibilityIdentifier("SignUpPrefillTestDataButton")
                }
                #endif
            }
        }
        .alert("Registration Error", isPresented: self.$coordinator.showAlert) {
            Button("OK") { }
        } message: {
            Text(self.coordinator.alertMessage)
        }
        .alert("Session Timeout", isPresented: self.$coordinator.showTimeoutWarning) {
            Button("Continue Session") {
                self.coordinator.extendSession()
            }
            Button("End Session", role: .destructive) {
                self.coordinator.stopInactivityTimers()
                self.coordinator.requestDismissal()
            }
        } message: {
            Text(
                "Your session will expire in \(self.coordinator.timeoutCountdown) seconds due to inactivity. Sensitive data will be cleared for your security."
            )
        }
        .onAppear {
            self.coordinator.signUpData = self.signUpData
            self.coordinator.setUserRole(self.signUpData.userRole)
            self.signUpData.injectServices(
                riskClassCalculationService: self.appServices.riskClassCalculationService,
                investmentExperienceCalculationService: self.appServices.investmentExperienceCalculationService
            )
            self.coordinator.setValidation(
                DefaultStepValidation(testModeService: self.appServices.testModeService)
            )
            self.coordinator.configureServices(
                onboardingAPIService: self.appServices.onboardingAPIService,
                userService: self.appServices.userService,
                termsContentService: self.appServices.termsContentService,
                telemetryService: self.appServices.telemetryService
            )
            Task {
                await self.coordinator.resumeOnboarding()
                #if DEBUG
                self.applyDebugTestPrefill(force: false)
                #endif
                self.coordinator.applyServerRoleToSignUpData()
                self.coordinator.startInactivityTimer()
            }
        }
        .onChange(of: self.signUpData.userRole) { _, newRole in
            guard !self.isAccountRoleLocked else { return }
            self.coordinator.setUserRole(newRole)
        }
        .onChange(of: self.coordinator.currentStep) { _, newStep in
            #if DEBUG
            if newStep == .emailVerification || newStep == .phoneVerification {
                self.coordinator.handleDebugVerificationStepEntered(newStep)
            }
            #else
            if newStep == .emailVerification {
                self.coordinator.sendVerificationCode()
            } else if newStep == .phoneVerification {
                self.coordinator.sendPhoneVerificationCode()
            }
            #endif
        }
        .onChange(of: self.coordinator.shouldDismiss) { _, newValue in
            if newValue {
                SignUpFlowSession.markUserLeftOnboarding()
                SignUpFlowSession.end()
                self.dismiss()
                self.coordinator.shouldDismiss = false
            }
        }
        .onDisappear {
            self.coordinator.stopInactivityTimers()
            self.coordinator.trackDropOffIfNeeded()
        }
        .fullScreenCover(isPresented: self.$coordinator.showWelcomePage) {
            WelcomePage(coordinator: self.coordinator)
        }
        .fullScreenCover(isPresented: self.$coordinator.showCompanyKyb) {
            if let kybService = appServices.companyKybAPIService {
                CompanyKybView(companyKybAPIService: kybService)
                    .environment(\.appServices, self.appServices)
            }
        }
        .sheet(isPresented: self.$showTermsOfService) {
            TermsOfServiceView(
                configurationService: self.appServices.configurationService,
                termsContentService: self.appServices.termsContentService
            )
        }
    }

    private var signUpFooter: some View {
        SignUpNavigationButtons(
            coordinator: self.coordinator,
            signUpData: self.signUpData,
            onComplete: self.completeRegistration,
            onShowTermsOfService: { self.showTermsOfService = true }
        )
        .padding(.horizontal, ResponsiveDesign.mainHorizontalPadding())
        .padding(.top, ResponsiveDesign.spacing(12))
        .padding(.bottom, ResponsiveDesign.spacing(8))
        .background {
            VStack(spacing: ResponsiveDesign.spacing(0)) {
                Rectangle()
                    .fill(AppTheme.fontColor.opacity(0.1))
                    .frame(height: 1)
                AppTheme.screenBackground.opacity(0.96)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch self.coordinator.currentStep {
        case .welcome:
            WelcomeStep(
                accountType: self.$signUpData.accountType,
                userRole: self.$signUpData.userRole,
                isRoleSelectionLocked: self.isAccountRoleLocked
            )
        case .contact:
            ContactStep(
                email: self.$signUpData.email,
                phoneNumber: self.$signUpData.phoneNumber,
                username: self.$signUpData.username,
                password: self.$signUpData.password,
                confirmPassword: self.$signUpData.confirmPassword,
                acceptedTerms: self.$signUpData.acceptedTerms,
                acceptedPrivacyPolicy: self.$signUpData.acceptedPrivacyPolicy
            )
        case .accountCreated:
            AccountCreatedStep()
        case .emailVerification:
            EmailVerificationStep(
                email: self.signUpData.email,
                verificationCode: self.$coordinator.verificationCode,
                isVerifying: self.coordinator.isVerifyingCode,
                errorMessage: self.coordinator.verificationError,
                canResend: self.coordinator.canResendCode,
                resendCountdown: self.coordinator.resendCountdown,
                onVerify: self.coordinator.verifyCode,
                onResend: self.coordinator.resendCode
            )
        case .phoneVerification:
            PhoneVerificationStep(
                phoneNumber: self.signUpData.phoneNumber,
                verificationCode: self.$coordinator.phoneVerificationCode,
                isVerifying: self.coordinator.isVerifyingPhone,
                errorMessage: self.coordinator.phoneVerificationError,
                canResend: self.coordinator.canResendPhoneCode,
                resendCountdown: self.coordinator.phoneResendCountdown,
                onVerify: self.coordinator.verifyPhoneCode,
                onResend: self.coordinator.resendPhoneCode
            )
        case .personalInfo:
            PersonalInfoStep(
                salutation: self.$signUpData.salutation,
                academicTitle: self.$signUpData.academicTitle,
                firstName: self.$signUpData.firstName,
                lastName: self.$signUpData.lastName,
                streetAndNumber: self.$signUpData.streetAndNumber,
                postalCode: self.$signUpData.postalCode,
                city: self.$signUpData.city,
                state: self.$signUpData.state,
                country: self.$signUpData.country,
                dateOfBirth: self.$signUpData.dateOfBirth,
                placeOfBirth: self.$signUpData.placeOfBirth,
                countryOfBirth: self.$signUpData.countryOfBirth
            )
        case .citizenshipTax:
            CitizenshipTaxStep(
                isNotUSCitizen: self.$signUpData.isNotUSCitizen,
                nationality: self.$signUpData.nationality,
                taxNumber: self.$signUpData.taxNumber,
                additionalResidenceCountry: self.$signUpData.additionalResidenceCountry,
                additionalTaxNumber: self.$signUpData.additionalTaxNumber,
                address: self.$signUpData.address,
                showAdditionalFields: self.$signUpData.showAdditionalFields
            )
        case .identificationType:
            IdentificationTypeStep(identificationType: self.$signUpData.identificationType)
        case .identificationUploadFront:
            IdentificationUploadFrontStep(
                identificationType: self.signUpData.identificationType,
                passportFrontImage: self.$signUpData.passportFrontImage,
                idCardFrontImage: self.$signUpData.idCardFrontImage
            )
        case .identificationUploadBack:
            IdentificationUploadBackStep(
                identificationType: self.signUpData.identificationType,
                passportBackImage: self.$signUpData.passportBackImage,
                idCardBackImage: self.$signUpData.idCardBackImage
            )
        case .postidentConfirmation:
            PostidentConfirmationStep(
                identificationConfirmed: self.$signUpData.identificationConfirmed
            )
        case .identificationConfirm:
            IdentificationConfirmStep(
                identificationType: self.signUpData.identificationType,
                passportFrontImage: self.signUpData.passportFrontImage,
                passportBackImage: self.signUpData.passportBackImage,
                idCardFrontImage: self.signUpData.idCardFrontImage,
                idCardBackImage: self.signUpData.idCardBackImage,
                identificationConfirmed: self.$signUpData.identificationConfirmed
            )
        case .addressConfirm:
            AddressConfirmStep(
                addressConfirmed: self.$signUpData.addressConfirmed,
                addressVerificationDocument: self.$signUpData.addressVerificationDocument
            )
        case .addressConfirmSuccess:
            AddressConfirmSuccessStep()
        case .financial:
            FinancialStep(
                employmentStatus: self.$signUpData.employmentStatus,
                income: self.$signUpData.income,
                incomeRange: self.$signUpData.incomeRange,
                incomeSources: self.$signUpData.incomeSources,
                otherIncomeSource: self.$signUpData.otherIncomeSource,
                cashAndLiquidAssets: self.$signUpData.cashAndLiquidAssets
            )
        case .experience:
            ExperienceStep(
                stocksTransactionsCount: self.$signUpData.stocksTransactionsCount,
                stocksInvestmentAmount: self.$signUpData.stocksInvestmentAmount,
                etfsTransactionsCount: self.$signUpData.etfsTransactionsCount,
                etfsInvestmentAmount: self.$signUpData.etfsInvestmentAmount,
                derivativesTransactionsCount: self.$signUpData.derivativesTransactionsCount,
                derivativesInvestmentAmount: self.$signUpData.derivativesInvestmentAmount,
                derivativesHoldingPeriod: self.$signUpData.derivativesHoldingPeriod,
                otherAssets: self.$signUpData.otherAssets
            )
        case .desiredReturn:
            DesiredReturnStep(signUpData: self.signUpData)
        case .nonInsiderDeclaration:
            NonInsiderDeclarationStep(insiderTradingOptions: self.$signUpData.insiderTradingOptions)
        case .moneyLaunderingDeclaration:
            MoneyLaunderingDeclarationStep(
                moneyLaunderingDeclaration: self.$signUpData.moneyLaunderingDeclaration,
                assetType: self.$signUpData.assetType
            )
        case .terms:
            TermsStep(
                acceptedTerms: self.$signUpData.acceptedTerms,
                acceptedPrivacyPolicy: self.$signUpData.acceptedPrivacyPolicy,
                acceptedMarketingConsent: self.$signUpData.acceptedMarketingConsent
            )
        case .summary:
            SummaryStep(signUpData: self.signUpData, coordinator: self.coordinator)
        case .riskClassificationNote:
            RiskClassificationNoteStep(signUpData: self.signUpData, coordinator: self.coordinator)
        case .riskClass7Confirmation:
            RiskClass7ConfirmationStep(signUpData: self.signUpData, coordinator: self.coordinator)
        case .roleAgreement:
            RoleAgreementStep(
                signUpData: self.signUpData,
                coordinator: self.coordinator,
                termsContentService: self.appServices.termsContentService,
                roleAgreementConsentService: RoleAgreementConsentService(
                    parseAPIClient: self.appServices.parseAPIClient
                )
            )
        }
    }

    #if DEBUG
    private func applyDebugTestPrefill(force: Bool) {
        self.coordinator.applyDebugTestPrefillIfNeeded(
            to: self.signUpData,
            testModeService: self.appServices.testModeService,
            force: force
        )
    }
    #endif

    /// Role is fixed at `POST /users` (Contact step); no changes after account exists.
    private var isAccountRoleLocked: Bool {
        self.appServices.userService.isAuthenticated
    }

    private func completeRegistration() {
        self.coordinator.isLoading = true

        Task {
            do {
                try await self.coordinator.finalizeRegistration(
                    signUpData: self.signUpData,
                    appServices: self.appServices
                )
                self.coordinator.isLoading = false
                self.dismiss()
            } catch {
                self.coordinator.isLoading = false
                self.coordinator.showError(error.localizedDescription)
            }
        }
    }
}

#Preview {
    SignUpView()
}
