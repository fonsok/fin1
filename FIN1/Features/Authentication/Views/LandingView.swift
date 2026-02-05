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

    // MARK: - Constants

    private static let taglineText = "Meeting Point for\ncalculated\nHigh-Gain, High-Risk\nInvestors & Traders"
    private static let getStartedButtonText = "Get Started"
    private static let signInButtonText = "Sign In"
    private static let platformSubtitleText = "Pool Investing Platform"

    private static let featureTexts: [(icon: String, text: String)] = [
        ("chart.bar.fill", "Fair Investment Pool System"),
        ("percent", "Proportional Profit Sharing"),
        ("shield.fill", "Risk Management"),
        ("chart.line.uptrend.xyaxis", "Added Value Trading")
    ]

    init(userService: any UserServiceProtocol) {
        self._viewModel = StateObject(wrappedValue: LandingViewModel(userService: userService))
    }

    var body: some View {
        Group {
            if viewModel.designStyle == .typewriter {
                typewriterStyleBody
            } else {
                originalStyleBody
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

    // MARK: - Original Style Body

    private var originalStyleBody: some View {
        ZStack {
            // Background
            AppTheme.screenBackground
                .ignoresSafeArea()
                .accessibilityIdentifier("LandingViewBackground")

            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(40)) {
                    // Top spacing
                    Spacer()
                        .frame(height: 16)

                    // Action Buttons (top)
                    VStack(spacing: ResponsiveDesign.spacing(16)) {
                        HStack(spacing: ResponsiveDesign.spacing(12)) {
                            Button(action: { showSignUp = true }, label: {
                                Text(Self.getStartedButtonText)
                                    .font(ResponsiveDesign.headlineFont())
                                    .foregroundColor(AppTheme.screenBackground)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(AppTheme.accentLightBlue)
                                    .cornerRadius(ResponsiveDesign.spacing(12))
                            })

                            Button(action: { showLogin = true }, label: {
                                Text(Self.signInButtonText)
                                    .font(ResponsiveDesign.headlineFont())
                                    .foregroundColor(AppTheme.accentLightBlue)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                                            .stroke(AppTheme.accentLightBlue, lineWidth: 2)
                                    )
                            })
                        }

                        #if DEBUG
                        // Debug toggle button
                        Button(action: { viewModel.showDebugButtons.toggle() }, label: {
                            HStack {
                                Image(systemName: viewModel.showDebugButtons ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12))
                                Text("Debug")
                                    .font(ResponsiveDesign.captionFont())
                                Spacer()
                            }
                            .foregroundColor(AppTheme.accentLightBlue.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(AppTheme.accentLightBlue.opacity(0.1))
                            .cornerRadius(ResponsiveDesign.spacing(8))
                        })
                        .accessibilityIdentifier("DebugToggleButton")

                        if viewModel.showDebugButtons {
                            // Test user buttons (only visible in DEBUG mode)
                            VStack(spacing: ResponsiveDesign.spacing(8)) {
                                // Test Investors
                            VStack(spacing: ResponsiveDesign.spacing(6)) {
                                Text("Test Investors")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.tertiaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                ForEach(1...5, id: \.self) { number in
                                    Button(action: {
                                        Task {
                                            await viewModel.signInAsInvestor(number: number)
                                        }
                                    }, label: {
                                        Text("Test: Sign In as Investor \(number)")
                                            .font(ResponsiveDesign.captionFont())
                                            .foregroundColor(AppTheme.accentLightBlue.opacity(0.8))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 32)
                                            .background(Color.clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                                                    .stroke(AppTheme.accentLightBlue.opacity(0.3), lineWidth: 1)
                                            )
                                    })
                                    .accessibilityIdentifier("LoginInvestor\(number)Button")
                                    .disabled(viewModel.isLoading)
                                }
                            }

                            // Test Traders
                            VStack(spacing: ResponsiveDesign.spacing(6)) {
                                Text("Test Traders")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.tertiaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                ForEach(1...3, id: \.self) { number in
                                    Button(action: {
                                        Task {
                                            await viewModel.signInAsTrader(number: number)
                                        }
                                    }, label: {
                                        Text("Test: Sign In as Trader \(number)")
                                            .font(ResponsiveDesign.captionFont())
                                            .foregroundColor(AppTheme.accentGreen.opacity(0.8))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 32)
                                            .background(Color.clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                                                    .stroke(AppTheme.accentGreen.opacity(0.3), lineWidth: 1)
                                            )
                                    })
                                    .accessibilityIdentifier("LoginTrader\(number)Button")
                                    .disabled(viewModel.isLoading)
                                }
                            }

                            // Test Admin
                            VStack(spacing: ResponsiveDesign.spacing(6)) {
                                Text("Test Admin")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.tertiaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Button(action: {
                                    Task {
                                        await viewModel.signInAsAdmin()
                                    }
                                }, label: {
                                    Text("Test: Sign In as Admin")
                                        .font(ResponsiveDesign.captionFont())
                                        .foregroundColor(AppTheme.accentLightBlue.opacity(0.8))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 32)
                                        .background(Color.clear)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                                                .stroke(AppTheme.accentLightBlue.opacity(0.3), lineWidth: 1)
                                        )
                                })
                                .accessibilityIdentifier("LoginAdminButton")
                                .disabled(viewModel.isLoading)
                            }

                            // Test CSR (3 agents)
                            VStack(spacing: ResponsiveDesign.spacing(6)) {
                                Text("Test CSR (Rollenbasiert)")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.tertiaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: ResponsiveDesign.spacing(8)) {
                                    ForEach(CSRRole.allCases, id: \.self) { role in
                                        Button(action: {
                                            Task {
                                                await viewModel.signInAsCSRWithRole(role)
                                            }
                                        }, label: {
                                            HStack(spacing: ResponsiveDesign.spacing(6)) {
                                                Image(systemName: role.icon)
                                                    .font(.system(size: 12))
                                                Text(role.shortName)
                                                    .font(ResponsiveDesign.captionFont())
                                            }
                                            .foregroundColor(role.color.opacity(0.9))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 32)
                                            .background(Color.clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                                                    .stroke(role.color.opacity(0.3), lineWidth: 1)
                                            )
                                        })
                                        .accessibilityIdentifier("LoginCSR\(role.rawValue)Button")
                                        .disabled(viewModel.isLoading)
                                    }
                                }
                            }
                            }
                        }
                        #endif
                    }
                    .padding(.horizontal, 32)

                    // Logo and Title
                    VStack(spacing: ResponsiveDesign.spacing(20)) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 80))
                            .foregroundColor(AppTheme.accentLightBlue)

                        Text(AppBrand.appName)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.fontColor)

                        Text(Self.platformSubtitleText)
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    // Features Section
                    VStack(spacing: ResponsiveDesign.spacing(16)) {
                        Text(Self.taglineText)
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(AppTheme.fontColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        VStack(spacing: ResponsiveDesign.spacing(12)) {
                            ForEach(Array(Self.featureTexts.enumerated()), id: \.offset) { _, feature in
                                FeatureRow(icon: feature.icon, text: feature.text, style: .original)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Platform Advantages Section
                    LandingPlatformAdvantagesView(style: .original)

                    // FAQ Section
                    LandingFAQView(style: .original)

                    landingLegalLinksSection(style: .original)

                    Spacer().frame(height: 24)

                    // Design Style Toggle at bottom
                    LandingDesignStyleToggleView(designStyle: $viewModel.designStyle)
                }
            }
        }
    }

    // MARK: - Typewriter Style Body

    private var typewriterStyleBody: some View {
        ZStack {
            // Background - White like paper with opacity 0.7
            Color.white.opacity(0.7)
                .ignoresSafeArea()
                .accessibilityIdentifier("LandingViewBackground")

            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(40)) {
                    // Top spacing
                    Spacer()
                        .frame(height: ResponsiveDesign.spacing(4))

                    // Action Buttons (top) - Plain text style, one row
                    VStack(spacing: ResponsiveDesign.spacing(16)) {
                        HStack(spacing: ResponsiveDesign.spacing(20)) {
                            Button(action: { showSignUp = true }, label: {
                                Text(Self.getStartedButtonText)
                                    .font(ResponsiveDesign.monospacedFont(size: 16, weight: .regular))
                                    .foregroundColor(Color("InputText"))
                                    .frame(maxWidth: .infinity)
                            })
                            .buttonStyle(PlainButtonStyle())

                            Button(action: { showLogin = true }, label: {
                                Text(Self.signInButtonText)
                                    .font(ResponsiveDesign.monospacedFont(size: 16, weight: .regular))
                                    .foregroundColor(Color("InputText"))
                                    .frame(maxWidth: .infinity)
                            })
                            .buttonStyle(PlainButtonStyle())
                        }

                        #if DEBUG
                        LandingDebugSectionView(viewModel: viewModel)
                        #endif
                    }
                    .padding(.horizontal, ResponsiveDesign.horizontalPadding())

                    // Logo and Title - Plain text style
                    VStack(spacing: ResponsiveDesign.spacing(20)) {
                        Text(AppBrand.appName)
                            .font(ResponsiveDesign.monospacedFont(size: 48, weight: .bold))
                            .foregroundColor(Color("InputText"))

                        Text(Self.platformSubtitleText)
                            .font(ResponsiveDesign.monospacedFont(size: 18, weight: .regular))
                            .foregroundColor(Color("InputText"))
                            .multilineTextAlignment(.center)
                    }

                    // Features Section - Plain text style
                    VStack(spacing: ResponsiveDesign.spacing(16)) {
                        Text(Self.taglineText)
                            .font(ResponsiveDesign.monospacedFont(size: 18, weight: .bold))
                            .foregroundColor(Color("InputText"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        VStack(spacing: ResponsiveDesign.spacing(12)) {
                            ForEach(Array(Self.featureTexts.enumerated()), id: \.offset) { _, feature in
                                FeatureRow(icon: feature.icon, text: feature.text, style: .typewriter)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Platform Advantages Section
                    LandingPlatformAdvantagesView(style: .typewriter)

                    // FAQ Section
                    LandingFAQView(style: .typewriter)

                    landingLegalLinksSection(style: .typewriter)

                    Spacer().frame(height: ResponsiveDesign.spacing(6))

                    // Design Style Toggle at bottom
                    LandingDesignStyleToggleView(designStyle: $viewModel.designStyle)
                }
            }
        }
    }

    // MARK: - Legal Links (Best Practice)

    @ViewBuilder
    private func landingLegalLinksSection(style: LandingViewModel.DesignStyle) -> some View {
        let isTypewriter = style == .typewriter

        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Rectangle()
                .fill(isTypewriter ? Color("InputText").opacity(0.4) : AppTheme.fontColor.opacity(0.2))
                .frame(height: 1)

            HStack(spacing: ResponsiveDesign.spacing(16)) {
                Button(action: { showLegalTerms = true }) {
                    Text("Terms")
                        .font(isTypewriter
                              ? ResponsiveDesign.monospacedFont(size: 14, weight: .regular)
                              : ResponsiveDesign.captionFont())
                        .foregroundColor(isTypewriter ? Color("InputText") : AppTheme.accentLightBlue)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { showLegalPrivacy = true }) {
                    Text("Privacy")
                        .font(isTypewriter
                              ? ResponsiveDesign.monospacedFont(size: 14, weight: .regular)
                              : ResponsiveDesign.captionFont())
                        .foregroundColor(isTypewriter ? Color("InputText") : AppTheme.accentLightBlue)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { showLegalImprint = true }) {
                    Text("Imprint")
                        .font(isTypewriter
                              ? ResponsiveDesign.monospacedFont(size: 14, weight: .regular)
                              : ResponsiveDesign.captionFont())
                        .foregroundColor(isTypewriter ? Color("InputText") : AppTheme.accentLightBlue)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()
            }
        }
        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    let style: LandingViewModel.DesignStyle
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            if style == .typewriter {
                Text("-")
                    .font(ResponsiveDesign.monospacedFont(size: 16, weight: .regular))
                    .foregroundColor(Color("InputText"))
            } else {
                Image(systemName: icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.accentGreen)
                    .frame(width: 24)
            }

            Text(text)
                .font(style == .typewriter
                      ? ResponsiveDesign.monospacedFont(size: 16, weight: .regular)
                      : ResponsiveDesign.bodyFont())
                .foregroundColor(style == .typewriter ? Color("InputText") : AppTheme.primaryText)

            Spacer()
        }
    }
}

#Preview {
    LandingView(userService: UserService.shared)
}
