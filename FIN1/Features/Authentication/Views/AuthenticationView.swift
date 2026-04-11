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
            if isAuthenticated {
                ZStack {
                    MainTabView(services: services)
                        .accessibilityIdentifier("MainTabView")
                        .onAppear {
                            print("🏠 MainTabView appeared - User is authenticated")
                            checkTermsAcceptance()
                        }

                    if showTermsAcceptance {
                        TermsAcceptanceModalView(
                            termsAcceptanceService: services.termsAcceptanceService,
                            userService: services.userService,
                            parseAPIClient: services.parseAPIClient,
                            termsContentService: services.termsContentService
                        )
                        .zIndex(1000)
                    }
                }
                .fullScreenCover(isPresented: $showOnboardingResume) {
                    SignUpView()
                        .environment(\.appServices, services)
                }
                .fullScreenCover(isPresented: $showCompanyKybResume) {
                    if let kybService = services.companyKybAPIService {
                        CompanyKybView(companyKybAPIService: kybService)
                            .environment(\.appServices, services)
                    }
                }
                .fullScreenCover(isPresented: $showCompanyKybStatus) {
                    if let reviewStatus = companyKybReviewStatus {
                        CompanyKybStatusView(
                            status: reviewStatus,
                            onDismiss: { showCompanyKybStatus = false },
                            onResubmit: {
                                showCompanyKybStatus = false
                                showCompanyKybResume = true
                            }
                        )
                    }
                }
            } else {
                LandingView(userService: services.userService)
                    .accessibilityIdentifier("LandingView")
                    .onAppear {
                        print("🚪 LandingView appeared - User is not authenticated")
                    }
            }
        }
        .accessibilityIdentifier("AuthenticationView")
        .onAppear {
            isAuthenticated = services.userService.isAuthenticated
            if isAuthenticated {
                checkTermsAcceptance()
                checkOnboardingStatus()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignIn)) { _ in
            isAuthenticated = true
            print("🔍 AuthenticationView: User signed in")
            checkTermsAcceptance()
            checkOnboardingStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignOut)) { _ in
            isAuthenticated = false
            showTermsAcceptance = false
            showOnboardingResume = false
            showCompanyKybResume = false
            showCompanyKybStatus = false
            companyKybReviewStatus = nil
            print("🔍 AuthenticationView: User signed out")
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDataDidUpdate)) { _ in
            if isAuthenticated {
                checkTermsAcceptance()
                checkOnboardingStatus()
            }
        }
    }

    // MARK: - Onboarding Status

    private func checkOnboardingStatus() {
        guard let user = services.userService.currentUser else {
            showOnboardingResume = false
            showCompanyKybResume = false
            showCompanyKybStatus = false
            return
        }

        // Company accounts: KYB takes precedence over personal onboarding
        if user.accountType == .company {
            let kybStatus = user.companyKybStatus

            // Post-reset: status is 'draft' and completed is false -- re-enter wizard
            if kybStatus == "draft" && !user.companyKybCompleted {
                showCompanyKybResume = true
                showCompanyKybStatus = false
                showOnboardingResume = false
                return
            }

            if user.companyKybCompleted {
                if let status = CompanyKybReviewStatus(from: kybStatus), status != .approved {
                    companyKybReviewStatus = status
                    showCompanyKybStatus = true
                } else {
                    showCompanyKybStatus = false
                }
                showCompanyKybResume = false
                showOnboardingResume = false
                return
            }

            if user.companyKybStep != nil {
                showCompanyKybResume = true
                showCompanyKybStatus = false
                showOnboardingResume = false
                return
            }
        }

        showCompanyKybResume = false
        showCompanyKybStatus = false
        showOnboardingResume = !user.onboardingCompleted && user.onboardingStep != nil
    }

    // MARK: - Private Methods

    private func checkTermsAcceptance() {
        guard let user = services.userService.currentUser else {
            showTermsAcceptance = false
            return
        }

        // Server-driven: determine current versions via TermsContentService (best effort).
        Task {
            let termsVersion = await resolveCurrentVersion(documentType: .terms)
            let privacyVersion = await resolveCurrentVersion(documentType: .privacy)

            let needsTerms = (user.acceptedTermsVersion ?? "") != termsVersion
            let needsPrivacy = (user.acceptedPrivacyPolicyVersion ?? "") != privacyVersion

            await MainActor.run {
                showTermsAcceptance = needsTerms || needsPrivacy
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
