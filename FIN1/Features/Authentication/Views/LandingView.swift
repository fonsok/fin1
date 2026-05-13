import SwiftUI

struct LandingView: View {
    @State private var showLogin = false
    @State private var showSignUp = false
    @State private var showLegalTerms = false
    @State private var showLegalPrivacy = false
    @State private var showLegalImprint = false
    @StateObject private var viewModel: LandingViewModel
    @Environment(\.appServices) private var appServices
    @Environment(\.themeManager) private var themeManager

    init(userService: any UserServiceProtocol) {
        self._viewModel = StateObject(wrappedValue: LandingViewModel(userService: userService))
    }

    var body: some View {
        Group {
            if self.viewModel.designStyle == .typewriter {
                LandingTypewriterStyleBody(
                    viewModel: self.viewModel,
                    showLogin: self.$showLogin,
                    showSignUp: self.$showSignUp,
                    showLegalTerms: self.$showLegalTerms,
                    showLegalPrivacy: self.$showLegalPrivacy,
                    showLegalImprint: self.$showLegalImprint
                )
            } else {
                LandingOriginalStyleBody(
                    viewModel: self.viewModel,
                    showLogin: self.$showLogin,
                    showSignUp: self.$showSignUp,
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
        .fullScreenCover(isPresented: self.$showSignUp) {
            SignUpView()
        }
        .alert("Login Error", isPresented: self.$viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(self.viewModel.errorMessage ?? "An error occurred during login")
        }
    }
}

#Preview {
    LandingView(userService: UserService.shared)
}
