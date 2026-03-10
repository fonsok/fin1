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
            if viewModel.designStyle == .typewriter {
                LandingTypewriterStyleBody(
                    viewModel: viewModel,
                    showLogin: $showLogin,
                    showSignUp: $showSignUp,
                    showLegalTerms: $showLegalTerms,
                    showLegalPrivacy: $showLegalPrivacy,
                    showLegalImprint: $showLegalImprint
                )
            } else {
                LandingOriginalStyleBody(
                    viewModel: viewModel,
                    showLogin: $showLogin,
                    showSignUp: $showSignUp,
                    showLegalTerms: $showLegalTerms,
                    showLegalPrivacy: $showLegalPrivacy,
                    showLegalImprint: $showLegalImprint
                )
            }
        }
        .sheet(isPresented: $showLogin) {
            DirectLoginView()
                .environment(\.appServices, appServices)
        }
        .sheet(isPresented: $showLegalTerms) {
            TermsOfServiceView(
                configurationService: appServices.configurationService,
                termsContentService: appServices.termsContentService
            )
        }
        .sheet(isPresented: $showLegalPrivacy) {
            PrivacyPolicyView(
                userService: appServices.userService,
                termsContentService: appServices.termsContentService
            )
        }
        .sheet(isPresented: $showLegalImprint) {
            ImprintView(termsContentService: appServices.termsContentService)
        }
        .fullScreenCover(isPresented: $showSignUp) {
            SignUpView()
        }
        .alert("Login Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred during login")
        }
    }
}

#Preview {
    LandingView(userService: UserService.shared)
}
