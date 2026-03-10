import SwiftUI

struct LandingOriginalStyleBody: View {
    @ObservedObject var viewModel: LandingViewModel
    @Binding var showLogin: Bool
    @Binding var showSignUp: Bool
    @Binding var showLegalTerms: Bool
    @Binding var showLegalPrivacy: Bool
    @Binding var showLegalImprint: Bool

    var body: some View {
        ZStack {
            AppTheme.screenBackground
                .ignoresSafeArea()
                .accessibilityIdentifier("LandingViewBackground")

            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(40)) {
                    Spacer()
                        .frame(height: 16)

                    VStack(spacing: ResponsiveDesign.spacing(16)) {
                        HStack(spacing: ResponsiveDesign.spacing(12)) {
                            Button(action: { showSignUp = true }, label: {
                                Text(LandingConstants.getStartedButtonText)
                                    .font(ResponsiveDesign.headlineFont())
                                    .foregroundColor(AppTheme.screenBackground)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(AppTheme.accentLightBlue)
                                    .cornerRadius(ResponsiveDesign.spacing(12))
                            })

                            Button(action: { showLogin = true }, label: {
                                Text(LandingConstants.signInButtonText)
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
                        Button(action: { viewModel.showDebugButtons.toggle() }, label: {
                            HStack {
                                Image(systemName: viewModel.showDebugButtons ? "chevron.up" : "chevron.down")
                                    .font(ResponsiveDesign.captionFont())
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
                            VStack(spacing: ResponsiveDesign.spacing(8)) {
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
                                                        .font(ResponsiveDesign.captionFont())
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

                    VStack(spacing: ResponsiveDesign.spacing(20)) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: ResponsiveDesign.iconSize() * 4))
                            .foregroundColor(AppTheme.accentLightBlue)

                        Text(AppBrand.appName)
                            .font(.system(size: ResponsiveDesign.iconSize() * 2.4, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.fontColor)

                        Text(LandingConstants.platformSubtitleText)
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: ResponsiveDesign.spacing(16)) {
                        Text(LandingConstants.taglineText)
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(AppTheme.fontColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        VStack(spacing: ResponsiveDesign.spacing(12)) {
                            ForEach(Array(LandingConstants.featureTexts.enumerated()), id: \.offset) { _, feature in
                                FeatureRow(icon: feature.icon, text: feature.text, style: .original)
                            }
                        }
                        .padding(.horizontal)
                    }

                    LandingPlatformAdvantagesView(style: .original)
                    LandingFAQView(style: .original)
                    LandingLegalLinksSection(
                        showLegalTerms: $showLegalTerms,
                        showLegalPrivacy: $showLegalPrivacy,
                        showLegalImprint: $showLegalImprint,
                        style: .original
                    )

                    Spacer().frame(height: 24)
                    LandingDesignStyleToggleView(designStyle: $viewModel.designStyle)
                }
            }
        }
    }
}
