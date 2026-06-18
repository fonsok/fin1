import SwiftUI

extension LeveragedProductsLearningView {
    // MARK: - Striped layout (admin-portal list row striping)

    func stripedBand<Content: View>(
        index: Int,
        anchor: LearningAnchor?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())
            .padding(.vertical, ResponsiveDesign.spacing(20))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                StripedListStyle.listRowBackground(index: index)
            }
            .id(anchor?.id)
    }

    // MARK: - Sections

    func flowSection(icon: String, title: String, accent: Color, body: String) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: icon)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(accent)
                    .frame(width: 36, height: 36)
                    .background(accent.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10)))

                Text(title)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer(minLength: 0)
            }

            Text(body)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.82))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var formulasSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(14)) {
            self.sectionDivider(title: "Formeln zum Laufzeitende", icon: "function")

            Text(LeveragedProductsLearningExamples.formulaIntro)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.82))

            self.formulaCard(
                label: "Call",
                formula: LeveragedProductsLearningExamples.callFormulaAtExpiry,
                accent: AppTheme.accentGreen
            )
            self.formulaCard(
                label: "Put",
                formula: LeveragedProductsLearningExamples.putFormulaAtExpiry,
                accent: AppTheme.accentOrange
            )

            Text(LeveragedProductsLearningExamples.examplesIntro)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
    }

    var workedExamplesSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            self.sectionDivider(title: "Rechenbeispiele", icon: "list.number")

            self.workedExampleAccordion(
                id: "call-example",
                title: "Call auf Aktie XYZ",
                subtitle: "Spekulation auf steigende Kurse",
                icon: "arrow.up.right.circle.fill",
                accent: AppTheme.accentGreen,
                setup: LeveragedProductsLearningExamples.callExampleSetup,
                scenarios: [
                    .init(title: "Gewinn — Kurs steigt auf 130 €", tone: .gain, text: LeveragedProductsLearningExamples.callScenarioAGain),
                    .init(title: "Verlust — Kurs unter 100 €", tone: .loss, text: LeveragedProductsLearningExamples.callScenarioBLoss)
                ]
            )

            self.workedExampleAccordion(
                id: "put-example",
                title: "Put auf Aktie XYZ",
                subtitle: "Spekulation auf fallende Kurse",
                icon: "arrow.down.right.circle.fill",
                accent: AppTheme.accentOrange,
                setup: LeveragedProductsLearningExamples.putExampleSetup,
                scenarios: [
                    .init(title: "Gewinn — Kurs fällt auf 40 €", tone: .gain, text: LeveragedProductsLearningExamples.putScenarioAGain),
                    .init(title: "Verlust — Kurs über 50 €", tone: .loss, text: LeveragedProductsLearningExamples.putScenarioBLoss)
                ]
            )

            self.workedExampleAccordion(
                id: "bmw-example",
                title: "Call auf BMW AG",
                subtitle: "Konkretes Aktienbeispiel",
                icon: "car.fill",
                accent: AppTheme.accentLightBlue,
                setup: LeveragedProductsLearningExamples.bmwExampleBody,
                scenarios: []
            )
        }
    }

    var beforeExpiryCallout: some View {
        HStack(alignment: .top, spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.accentLightBlue)
                .padding(.top, 2)

            Text(LeveragedProductsLearningExamples.beforeExpiryNote)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.85))
                .multilineTextAlignment(.leading)
        }
        .padding(ResponsiveDesign.spacing(16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accentLightBlue.opacity(0.1))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(2))
                .fill(AppTheme.accentLightBlue)
                .frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12)))
    }

    func externalLinkButton(url: URL) -> some View {
        Button {
            self.openURL(url)
        } label: {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: "safari")
                    .font(ResponsiveDesign.headlineFont())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weitere Informationen im Internet")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                    Text("Externe Ressource öffnen")
                        .font(ResponsiveDesign.captionFont())
                        .opacity(0.75)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
            }
            .foregroundColor(AppTheme.accentLightBlue)
            .padding(ResponsiveDesign.spacing(16))
            .background(AppTheme.screenBackground.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12)))
        }
        .buttonStyle(PlainButtonStyle())
    }
}
