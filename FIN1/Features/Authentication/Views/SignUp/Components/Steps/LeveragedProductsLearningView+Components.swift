import SwiftUI

extension LeveragedProductsLearningView {
    // MARK: - Components

    func sectionDivider(title: String, icon: String) -> some View {
        HStack(spacing: ResponsiveDesign.spacing(10)) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.accentLightBlue)
            Text(title)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
            Spacer(minLength: 0)
        }
    }

    func formulaCard(label: String, formula: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text(label.uppercased())
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.bold)
                .foregroundColor(accent)

            Text(formula)
                .font(ResponsiveDesign.monospacedFont(size: 14, weight: .medium))
                .foregroundColor(AppTheme.fontColor)
                .multilineTextAlignment(.leading)
        }
        .padding(ResponsiveDesign.spacing(14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.screenBackground.opacity(0.45))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(2))
                .fill(accent)
                .frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12)))
    }

    func workedExampleAccordion(
        id: String,
        title: String,
        subtitle: String,
        icon: String,
        accent: Color,
        setup: String,
        scenarios: [LearningScenarioItem]
    ) -> some View {
        let isExpanded = self.expandedExampleIDs.contains(id)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    if isExpanded {
                        self.expandedExampleIDs.remove(id)
                    } else {
                        self.expandedExampleIDs.insert(id)
                    }
                }
            } label: {
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    Image(systemName: icon)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(accent)
                        .frame(width: 40, height: 40)
                        .background(accent.opacity(0.14))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.fontColor)
                        Text(subtitle)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.65))
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))
                }
                .padding(ResponsiveDesign.spacing(16))
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                    Text(setup)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.85))
                        .multilineTextAlignment(.leading)

                    ForEach(scenarios) { scenario in
                        self.scenarioCard(scenario)
                    }
                }
                .padding(.horizontal, ResponsiveDesign.spacing(16))
                .padding(.bottom, ResponsiveDesign.spacing(16))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppTheme.screenBackground.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(14)))
    }

    func scenarioCard(_ scenario: LearningScenarioItem) -> some View {
        let accent = scenario.tone == .gain ? AppTheme.accentGreen : AppTheme.accentOrange
        let icon = scenario.tone == .gain ? "plus.circle.fill" : "minus.circle.fill"

        return HStack(alignment: .top, spacing: ResponsiveDesign.spacing(12)) {
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(2))
                .fill(accent)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Label(scenario.title, systemImage: icon)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(accent)

                Text(scenario.text)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.85))
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(ResponsiveDesign.spacing(12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.sectionBackground.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10)))
    }
}
