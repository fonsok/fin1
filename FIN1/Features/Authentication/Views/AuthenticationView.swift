import SwiftUI

// MARK: - Authentication View
/// Root view that handles authentication state and shows appropriate content
struct AuthenticationView: View {
    @Environment(\.appServices) var services
    @StateObject var session = UserSessionObserver()
    @State var showTermsAcceptance = false
    @State var showReConsent = false
    @State var isResolvingLegalConsentGate = false
    @State var isSignUpPresented = false
    @State var showCompanyKybResume = false
    @State var showCompanyKybStatus = false
    @State var companyKybReviewStatus: CompanyKybReviewStatus?
    @State var onboardingRePresentTask: Task<Void, Never>?
    @State var reConsentViewModel: ReConsentViewModel?

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
            self.showReConsent = false
            self.isSignUpPresented = false
            self.onboardingRePresentTask?.cancel()
            self.onboardingRePresentTask = nil
            SignUpFlowSession.reset()
            self.showCompanyKybResume = false
            self.showCompanyKybStatus = false
            self.companyKybReviewStatus = nil
            self.reConsentViewModel = nil
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
        .onReceive(NotificationCenter.default.publisher(for: .reConsentCompleted)) { _ in
            Task {
                await self.evaluateReConsentRequirement(showOnlyIfNeeded: true)
            }
        }
    }
}
