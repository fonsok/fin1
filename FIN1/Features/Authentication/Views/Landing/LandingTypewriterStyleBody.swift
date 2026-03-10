import SwiftUI

struct LandingTypewriterStyleBody: View {
    @ObservedObject var viewModel: LandingViewModel
    @Binding var showLogin: Bool
    @Binding var showSignUp: Bool
    @Binding var showLegalTerms: Bool
    @Binding var showLegalPrivacy: Bool
    @Binding var showLegalImprint: Bool

    var body: some View {
        ZStack {
            Color.white.opacity(0.7)
                .ignoresSafeArea()
                .accessibilityIdentifier("LandingViewBackground")

            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(40)) {
                    Spacer()
                        .frame(height: ResponsiveDesign.spacing(4))

                    VStack(spacing: ResponsiveDesign.spacing(16)) {
                        HStack(spacing: ResponsiveDesign.spacing(20)) {
                            Button(action: { showSignUp = true }, label: {
                                Text(LandingConstants.getStartedButtonText)
                                    .font(ResponsiveDesign.monospacedFont(size: 16, weight: .regular))
                                    .foregroundColor(Color("InputText"))
                                    .frame(maxWidth: .infinity)
                            })
                            .buttonStyle(PlainButtonStyle())

                            Button(action: { showLogin = true }, label: {
                                Text(LandingConstants.signInButtonText)
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

                    VStack(spacing: ResponsiveDesign.spacing(20)) {
                        Text(AppBrand.appName)
                            .font(ResponsiveDesign.monospacedFont(size: 48, weight: .bold))
                            .foregroundColor(Color("InputText"))

                        Text(LandingConstants.platformSubtitleText)
                            .font(ResponsiveDesign.monospacedFont(size: 18, weight: .regular))
                            .foregroundColor(Color("InputText"))
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: ResponsiveDesign.spacing(16)) {
                        Text(LandingConstants.taglineText)
                            .font(ResponsiveDesign.monospacedFont(size: 18, weight: .bold))
                            .foregroundColor(Color("InputText"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        VStack(spacing: ResponsiveDesign.spacing(12)) {
                            ForEach(Array(LandingConstants.featureTexts.enumerated()), id: \.offset) { _, feature in
                                FeatureRow(icon: feature.icon, text: feature.text, style: .typewriter)
                            }
                        }
                        .padding(.horizontal)
                    }

                    LandingPlatformAdvantagesView(style: .typewriter)
                    LandingFAQView(style: .typewriter)
                    LandingLegalLinksSection(
                        showLegalTerms: $showLegalTerms,
                        showLegalPrivacy: $showLegalPrivacy,
                        showLegalImprint: $showLegalImprint,
                        style: .typewriter
                    )

                    Spacer().frame(height: ResponsiveDesign.spacing(6))
                    LandingDesignStyleToggleView(designStyle: $viewModel.designStyle)
                }
            }
        }
    }
}
