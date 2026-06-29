import SwiftUI

extension AuthenticationView {

    var authenticatedMainContent: some View {
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

            if self.showReConsent, let reConsentViewModel = self.reConsentViewModel {
                ReConsentModalView(viewModel: reConsentViewModel)
                    .zIndex(1_001)
            }
        }
        .onChange(of: self.showReConsent) { _, isPresented in
            if isPresented {
                if self.reConsentViewModel == nil {
                    self.reConsentViewModel = self.makeReConsentViewModel()
                } else {
                    self.reConsentViewModel?.loadFromCurrentUser()
                }
            } else {
                self.reConsentViewModel = nil
            }
        }
    }

    var legalConsentGatePlaceholder: some View {
        ZStack {
            AppTheme.screenBackground
                .ignoresSafeArea()
            ProgressView()
                .tint(AppTheme.accentLightBlue)
                .scaleEffect(1.2)
        }
        .accessibilityIdentifier("LegalConsentGatePlaceholder")
    }
}
