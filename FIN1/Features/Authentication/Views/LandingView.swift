import SwiftUI

struct LandingView: View {
    @State private var showLogin = false
    @Binding var isSignUpPresented: Bool
    @State private var showLegalTerms = false
    @State private var showLegalPrivacy = false
    @State private var showLegalImprint = false
    @StateObject private var viewModel: LandingViewModel
    @Environment(\.appServices) private var appServices
    @Environment(\.themeManager) private var themeManager

    init(userService: any UserServiceProtocol, isSignUpPresented: Binding<Bool>) {
        self._isSignUpPresented = isSignUpPresented
        self._viewModel = StateObject(wrappedValue: LandingViewModel(userService: userService))
    }

    private var presentSignUpBinding: Binding<Bool> {
        Binding(
            get: { self.isSignUpPresented },
            set: { newValue in
                if newValue {
                    SignUpFlowSession.beginFromLanding()
                } else {
                    SignUpFlowSession.end()
                }
                self.isSignUpPresented = newValue
            }
        )
    }

    var body: some View {
        Group {
            if self.viewModel.designStyle == .typewriter {
                LandingTypewriterStyleBody(
                    viewModel: self.viewModel,
                    showLogin: self.$showLogin,
                    showSignUp: self.presentSignUpBinding,
                    showLegalTerms: self.$showLegalTerms,
                    showLegalPrivacy: self.$showLegalPrivacy,
                    showLegalImprint: self.$showLegalImprint
                )
            } else {
                LandingOriginalStyleBody(
                    viewModel: self.viewModel,
                    showLogin: self.$showLogin,
                    showSignUp: self.presentSignUpBinding,
                    showLegalTerms: self.$showLegalTerms,
                    showLegalPrivacy: self.$showLegalPrivacy,
                    showLegalImprint: self.$showLegalImprint
                )
            }
        }
        .sheet(isPresented: self.$showLogin) {
            DirectLoginView()
                .environment(\.appServices, self.appServices)
        }
        .sheet(isPresented: self.$showLegalTerms) {
            TermsOfServiceView(
                configurationService: self.appServices.configurationService,
                termsContentService: self.appServices.termsContentService
            )
        }
        .sheet(isPresented: self.$showLegalPrivacy) {
            PrivacyPolicyView(
                userService: self.appServices.userService,
                termsContentService: self.appServices.termsContentService
            )
        }
        .sheet(isPresented: self.$showLegalImprint) {
            ImprintView(termsContentService: self.appServices.termsContentService)
        }
        .alert("Login Error", isPresented: self.$viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(self.viewModel.errorMessage ?? "An error occurred during login")
        }
    }
}

#Preview {
    LandingView(userService: UserService.shared, isSignUpPresented: .constant(false))
        .environment(\.appServices, AppServices.live)
}
