import SwiftUI

// MARK: - Authentication View
/// Root view that handles authentication state and shows appropriate content
struct AuthenticationView: View {
    @Environment(\.appServices) private var services
    @State private var isAuthenticated = false
    @State private var showTermsAcceptance = false
    @State private var showOnboardingResume = false
    @State private var showCompanyKybResume = false
    @State private var showCompanyKybStatus = false
    @State private var companyKybReviewStatus: CompanyKybReviewStatus?

    var body: some View {
        Group {
            if self.isAuthenticated {
                ZStack {
                    MainTabView(services: self.services)
                        .accessibilityIdentifier("MainTabView")
                        .onAppear {
                            print("🏠 MainTabView appeared - User is authenticated")
                            self.checkTermsAcceptance()
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
        .accessibilityIdentifier("AuthenticationView")
        .onAppear {
            self.isAuthenticated = self.services.userService.isAuthenticated
            if self.isAuthenticated {
                self.checkTermsAcceptance()
                self.checkOnboardingStatus()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignIn)) { _ in
            self.isAuthenticated = true
            print("🔍 AuthenticationView: User signed in")
            self.checkTermsAcceptance()
            self.checkOnboardingStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignOut)) { _ in
            self.isAuthenticated = false
            self.showTermsAcceptance = false
            self.showOnboardingResume = false
            self.showCompanyKybResume = false
            self.showCompanyKybStatus = false
            self.companyKybReviewStatus = nil
            print("🔍 AuthenticationView: User signed out")
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDataDidUpdate)) { _ in
            if self.isAuthenticated {
                self.checkTermsAcceptance()
                self.checkOnboardingStatus()
            }
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

    private func checkTermsAcceptance() {
        guard let user = services.userService.currentUser else {
            self.showTermsAcceptance = false
            return
        }

        // Server-driven: determine current versions via TermsContentService (best effort).
        Task {
            let termsVersion = await resolveCurrentVersion(documentType: .terms)
            let privacyVersion = await resolveCurrentVersion(documentType: .privacy)

            let needsTerms = (user.acceptedTermsVersion ?? "") != termsVersion
            let needsPrivacy = (user.acceptedPrivacyPolicyVersion ?? "") != privacyVersion

            await MainActor.run {
                self.showTermsAcceptance = needsTerms || needsPrivacy
            }
        }
    }

    private func resolveCurrentVersion(documentType: LegalDocumentType) async -> String {
        // Prefer cached (no network); then try server; then fallback to bundled constants.
        let language: TermsOfServiceDataProvider.Language = .german
        if let cached = services.termsContentService.getCachedTerms(language: language, documentType: documentType) {
            return cached.version
        }
        if let fetched = try? await services.termsContentService.fetchCurrentTerms(language: language, documentType: documentType) {
            return fetched.version
        }
        switch documentType {
        case .terms: return TermsVersionConstants.currentTermsVersion
        case .privacy: return TermsVersionConstants.currentPrivacyPolicyVersion
        case .imprint: return "1.0"
        }
    }
}
