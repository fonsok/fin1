import SwiftUI

// MARK: - Authentication View
/// Root view that handles authentication state and shows appropriate content
struct AuthenticationView: View {
    @Environment(\.appServices) private var services
    @State private var isAuthenticated = false
    @State private var showTermsAcceptance = false
    @State private var isResolvingLegalConsentGate = false
    @State private var showOnboardingResume = false
    @State private var showCompanyKybResume = false
    @State private var showCompanyKybStatus = false
    @State private var companyKybReviewStatus: CompanyKybReviewStatus?

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            Group {
                if self.isAuthenticated {
                    Group {
                        if self.isResolvingLegalConsentGate {
                            self.legalConsentGatePlaceholder
                        } else {
                            self.authenticatedMainContent
                        }
                    }
                    .fullScreenCover(isPresented: self.$showOnboardingResume) {
                        SignUpView()
                            .environment(\.appServices, self.services)
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
                    LandingView(userService: self.services.userService)
                        .accessibilityIdentifier("LandingView")
                        .onAppear {
                            print("🚪 LandingView appeared - User is not authenticated")
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("AuthenticationView")
        .onAppear {
            self.isAuthenticated = self.services.userService.isAuthenticated
            if self.isAuthenticated {
                self.beginLegalConsentGateCheck()
                self.checkOnboardingStatus()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignIn)) { _ in
            self.isAuthenticated = true
            print("🔍 AuthenticationView: User signed in")
            self.beginLegalConsentGateCheck()
            self.checkOnboardingStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignOut)) { _ in
            self.isAuthenticated = false
            self.isResolvingLegalConsentGate = false
            self.showTermsAcceptance = false
            self.showOnboardingResume = false
            self.showCompanyKybResume = false
            self.showCompanyKybStatus = false
            self.companyKybReviewStatus = nil
            print("🔍 AuthenticationView: User signed out")
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDataDidUpdate)) { _ in
            if self.isAuthenticated {
                self.showTermsAcceptanceModalIfStillRequired()
                self.checkOnboardingStatus()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .legalConsentAcceptanceCompleted)) { _ in
            self.showTermsAcceptance = false
        }
    }

    // MARK: - Onboarding Status

    private func checkOnboardingStatus() {
        guard let user = services.userService.currentUser else {
            self.showOnboardingResume = false
            self.showCompanyKybResume = false
            self.showCompanyKybStatus = false
            return
        }

        // Company accounts: KYB takes precedence over personal onboarding
        if user.accountType == .company {
            let kybStatus = user.companyKybStatus

            // Post-reset: status is 'draft' and completed is false -- re-enter wizard
            if kybStatus == "draft" && !user.companyKybCompleted {
                self.showCompanyKybResume = true
                self.showCompanyKybStatus = false
                self.showOnboardingResume = false
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
                self.showOnboardingResume = false
                return
            }

            if user.companyKybStep != nil {
                self.showCompanyKybResume = true
                self.showCompanyKybStatus = false
                self.showOnboardingResume = false
                return
            }
        }

        self.showCompanyKybResume = false
        self.showCompanyKybStatus = false
        self.showOnboardingResume = !user.onboardingCompleted && user.onboardingStep != nil
    }

    // MARK: - Private Methods

    private var authenticatedMainContent: some View {
        ZStack {
            MainTabView(services: self.services)
                .accessibilityIdentifier("MainTabView")
                .onAppear {
                    print("🏠 MainTabView appeared - User is authenticated")
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

        if let parseAPIClient = services.parseAPIClient {
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
            } else if !showOnlyIfNeeded {
                self.showTermsAcceptance = false
            }
            self.isResolvingLegalConsentGate = false
        }
    }
}
