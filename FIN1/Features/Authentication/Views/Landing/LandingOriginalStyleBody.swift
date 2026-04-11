import SwiftUI

struct LandingOriginalStyleBody: View {
    @ObservedObject var viewModel: LandingViewModel
    @Binding var showLogin: Bool
    @Binding var showSignUp: Bool
    @Binding var showLegalTerms: Bool
    @Binding var showLegalPrivacy: Bool
    @Binding var showLegalImprint: Bool
    #if DEBUG
    // Company KYB debug sheet is handled inside LandingDebugButtonsView
    #endif

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
                                LandingDebugButtonsView(viewModel: viewModel)
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

                        Text(LandingConstants.appSubtitleText)
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
