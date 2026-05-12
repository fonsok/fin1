import SwiftUI

/// App Advantages section for the landing page
/// Displays key advantages for investors and traders
struct LandingPlatformAdvantagesView: View {
    @State private var expandedSection: AdvantageSection?
    let style: LandingViewModel.DesignStyle

    // MARK: - Constants

    private static let sectionTitle = "App Advantages"
    private static let sectionSubtitle = "Discover why investors and traders choose our app"
    private static let investorsTitle = "Investors"
    private static let tradersTitle = "Traders"
    private static let differentiatorsTitle = "Key differences from traditional asset management"
    private static let investorsIntroText = "Investors on our app enjoy:"
    private static let tradersIntroText = "Traders on our app enjoy:"
    private static let differentiatorsIntroText = "What makes us different:"

    enum AdvantageSection {
        case investors
        case traders
        case differentiators
    }

    init(style: LandingViewModel.DesignStyle = .original) {
        self.style = style
    }

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(24)) {
            // Separator Line
            Rectangle()
                .fill(style == .typewriter ? Color("InputText") : AppTheme.fontColor.opacity(0.5))
                .frame(height: 1)
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())

            // Section Header
            VStack(spacing: ResponsiveDesign.spacing(8)) {
                if style == .typewriter {
                    Text(Self.sectionTitle)
                        .font(ResponsiveDesign.scaledSystemFont(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(Color("InputText"))
                } else {
                    HStack(spacing: ResponsiveDesign.spacing(8)) {
                        Image(systemName: "sparkles")
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(AppTheme.accentLightBlue)

                        Text(Self.sectionTitle)
                            .font(ResponsiveDesign.headlineFont())
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.fontColor)
                    }
                }

                Text(Self.sectionSubtitle)
                    .font(style == .typewriter
                          ? .system(size: 16, weight: .regular, design: .monospaced)
                          : ResponsiveDesign.bodyFont())
                    .foregroundColor(style == .typewriter ? Color("InputText") : AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, ResponsiveDesign.horizontalPadding())

            // Advantages Cards
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                // Differentiators
                advantageCard(
                    title: Self.differentiatorsTitle,
                    icon: nil,
                    color: AppTheme.accentOrange,
                    advantages: AppAdvantagesProvider.appDifferentiators,
                    section: .differentiators
                )
                
                // For Investors
                advantageCard(
                    title: Self.investorsTitle,
                    icon: nil,
                    color: AppTheme.accentGreen,
                    advantages: AppAdvantagesProvider.investorAdvantages,
                    section: .investors
                )

                // For Traders
                advantageCard(
                    title: Self.tradersTitle,
                    icon: nil,
                    color: AppTheme.accentLightBlue,
                    advantages: AppAdvantagesProvider.traderAdvantages,
                    section: .traders
                )


            }
            .padding(.horizontal, ResponsiveDesign.horizontalPadding())
        }
    }

    // MARK: - Helper Methods

    private func introductoryText(for section: AdvantageSection) -> String {
        switch section {
        case .investors:
            return Self.investorsIntroText
        case .traders:
            return Self.tradersIntroText
        case .differentiators:
            return Self.differentiatorsIntroText
        }
    }

    // MARK: - Advantage Card

    @ViewBuilder
    private func advantageCard(
        title: String,
        icon: String?,
        color: Color,
        advantages: [String],
        section: AdvantageSection
    ) -> some View {
        ExpandableSectionRow(
            title: title,
            icon: icon,
            iconColor: color,
            isExpanded: expandedSection == section,
            onToggle: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedSection == section {
                        expandedSection = nil
                    } else {
                        expandedSection = section
                    }
                }
            },
            style: style
        ) {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                // Introductory text
                Text(introductoryText(for: section))
                    .font(style == .typewriter
                          ? .system(size: 16, weight: .regular, design: .monospaced)
                          : ResponsiveDesign.bodyFont())
                    .foregroundColor(style == .typewriter ? Color("InputText") : AppTheme.fontColor.opacity(0.9))
                    .padding(.bottom, ResponsiveDesign.spacing(4))

                // Advantages list
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    ForEach(advantages, id: \.self) { advantage in
                        HStack(alignment: .top, spacing: ResponsiveDesign.spacing(10)) {
                            if style == .typewriter {
                                Text("-")
                                    .font(ResponsiveDesign.scaledSystemFont(size: 16, weight: .regular, design: .monospaced))
                                    .foregroundColor(Color("InputText"))
                                    .padding(.top, ResponsiveDesign.spacing(4))
                            } else {
                                Image(systemName: "circle.fill")
                                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.spacing(12)))
                                    .foregroundColor(AppTheme.fontColor.opacity(0.9))
                                    .padding(.top, ResponsiveDesign.spacing(4))
                            }

                            Text(advantage)
                                .font(style == .typewriter
                                      ? .system(size: 16, weight: .regular, design: .monospaced)
                                      : ResponsiveDesign.bodyFont())
                                .foregroundColor(style == .typewriter ? Color("InputText") : AppTheme.fontColor.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    VStack {
        LandingPlatformAdvantagesView(style: .original)
        LandingPlatformAdvantagesView(style: .typewriter)
    }
    .padding()
}
