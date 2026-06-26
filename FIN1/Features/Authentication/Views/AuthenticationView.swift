import SwiftUI

// MARK: - Authentication View
/// Root view that handles authentication state and shows appropriate content
struct AuthenticationView: View {
    @Environment(\.appServices) private var services
    @StateObject private var session = UserSessionObserver()
    @State private var showTermsAcceptance = false
    @State private var isResolvingLegalConsentGate = false
    @State private var isSignUpPresented = false
    @State private var showCompanyKybResume = false
    @State private var showCompanyKybStatus = false
    @State private var companyKybReviewStatus: CompanyKybReviewStatus?
    @State private var onboardingRePresentTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            Group {
                if self.session.isAuthenticated {
                    Group {
                        if self.isResolvingLegalConsentGate {
                            self.legalConsentGatePlaceholder
                        } else {
                            self.authenticatedMainContent
                        }
                    }
                    .fullScreenCover(isPresented: self.$showCompanyKybResume) {
                        if let kybService = services.companyKybAPIService {
                            CompanyKybView(companyKybAPIService: kybService)
                                .environment(\.appServices, self.services)
                        }
                    }
                    .fullScreenCover(isPresented: self.$showCompanyKybStatus) {
                        if let reviewStatus = companyKybReviewStatus {
                            CompanyKybStatusView(
                                status: reviewStatus,
                                onDismiss: { self.showCompanyKybStatus = false },
                                onResubmit: {
                                    self.showCompanyKybStatus = false
                                    self.showCompanyKybResume = true
                                }
                            )
                        }
                    }
                } else {
                    LandingView(
                        userService: self.services.userService,
                        isSignUpPresented: self.$isSignUpPresented
                    )
                    .accessibilityIdentifier("LandingView")
                    .onAppear {
                        print("🚪 LandingView appeared - User is not authenticated")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("AuthenticationView")
        .fullScreenCover(isPresented: self.$isSignUpPresented, onDismiss: {
            SignUpFlowSession.end()
            // Do not post userDataDidUpdate here — it used to call checkOnboardingStatus()
            // immediately and fight SwiftUI dismiss, causing onboarding flicker loops.
            self.scheduleOnboardingResumeIfNeededAfterDismiss()
        }) {
            SignUpView()
                .environment(\.appServices, self.services)
        }
        .onAppear {
            self.session.bind(to: self.services.userService)
            if self.session.isAuthenticated {
                self.beginLegalConsentGateCheck()
                self.checkOnboardingStatus()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignIn)) { _ in
            SignUpFlowSession.reset()
            print("🔍 AuthenticationView: User signed in")
            self.beginLegalConsentGateCheck()
            self.checkOnboardingStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignOut)) { _ in
            self.isResolvingLegalConsentGate = false
            self.showTermsAcceptance = false
            self.isSignUpPresented = false
            self.onboardingRePresentTask?.cancel()
            self.onboardingRePresentTask = nil
            SignUpFlowSession.reset()
            self.showCompanyKybResume = false
            self.showCompanyKybStatus = false
            self.companyKybReviewStatus = nil
            print("🔍 AuthenticationView: User signed out")
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDataDidUpdate)) { _ in
            if self.session.isAuthenticated {
                self.showTermsAcceptanceModalIfStillRequired()
                if self.session.onboardingCompleted {
                    self.isSignUpPresented = false
                    SignUpFlowSession.end()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .registrationDidFinalize)) { _ in
            self.isSignUpPresented = false
            SignUpFlowSession.end()
        }
        .onReceive(NotificationCenter.default.publisher(for: .legalConsentAcceptanceCompleted)) { _ in
            Task {
                await self.evaluateLegalConsentRequirement(showOnlyIfNeeded: false)
            }
        }
    }

    // MARK: - Onboarding Status

    private func checkOnboardingStatus() {
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
    private func scheduleOnboardingResumeIfNeededAfterDismiss() {
        self.onboardingRePresentTask?.cancel()
        self.onboardingRePresentTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            guard !SignUpFlowSession.userLeftOnboarding else { return }
            guard !self.isSignUpPresented else { return }
            self.checkOnboardingStatus()
        }
    }

    // MARK: - Private Methods

    private var authenticatedMainContent: some View {
        ZStack {
            if self.session.onboardingCompleted {
                MainTabView(services: self.services)
                    .accessibilityIdentifier("MainTabView")
                    .onAppear {
                        print("🏠 MainTabView appeared - User is authenticated")
                    }
            } else {
                OnboardingPausedView(
                    onContinue: {
                        SignUpFlowSession.resumeAfterExplicitPause()
                        self.isSignUpPresented = true
                    },
                    onSignOut: {
                        Task {
                            await self.services.userService.signOut()
                        }
                    }
                )
                .accessibilityIdentifier("OnboardingPausedView")
            }

            if self.showTermsAcceptance {
                TermsAcceptanceModalView(
                    termsAcceptanceService: self.services.termsAcceptanceService,
                    userService: self.services.userService,
                    parseAPIClient: self.services.parseAPIClient,
                    termsContentService: self.services.termsContentService
                )
                .zIndex(1_000)
            }
        }
    }

    private var legalConsentGatePlaceholder: some View {
        ZStack {
            AppTheme.screenBackground
                .ignoresSafeArea()
            ProgressView()
                .tint(AppTheme.accentLightBlue)
                .scaleEffect(1.2)
        }
        .accessibilityIdentifier("LegalConsentGatePlaceholder")
    }

    private func beginLegalConsentGateCheck() {
        self.isResolvingLegalConsentGate = true
        Task {
            await self.evaluateLegalConsentRequirement(showOnlyIfNeeded: false)
        }
    }

    /// Show blocking modal when consent is still required; never hide on partial acceptance.
    private func showTermsAcceptanceModalIfStillRequired() {
        Task {
            await self.evaluateLegalConsentRequirement(showOnlyIfNeeded: true)
        }
    }

    private func evaluateLegalConsentRequirement(showOnlyIfNeeded: Bool) async {
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
        await MainActor.run {
            if needsTerms || needsPrivacy {
                self.showTermsAcceptance = true
            } else {
                self.showTermsAcceptance = false
            }
            self.isResolvingLegalConsentGate = false
        }
    }
}
