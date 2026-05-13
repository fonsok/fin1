import SwiftUI

struct RiskClass7ConfirmationStep: View {
    let signUpData: SignUpData
    let coordinator: SignUpCoordinator
    @Environment(\.appServices) private var services
    @State private var maxLossWarningText: String = ""
    @State private var experiencedOnlyText: String = ""

    private var defaultMaxLossWarningText: String {
        "Das Verlustrisiko bis zu 100 % des eingesetzten Kapitals ist bekannt."
    }

    private var defaultExperiencedOnlyText: String {
        "Diese Risikoklasse ist nur für erfahrene Investoren geeignet."
    }

    private var combinedWarningText: String {
        let experienced = self.experiencedOnlyText.isEmpty ? self.defaultExperiencedOnlyText : self.experiencedOnlyText
        let maxLoss = self.maxLossWarningText.isEmpty ? self.defaultMaxLossWarningText : self.maxLossWarningText
        return "Sie haben Risikoklasse 7 ausgewählt. \(experienced) \(maxLoss)"
    }

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(24)) {
            // Header
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                Text("Risikoklasse 7 Bestätigung")
                    .font(ResponsiveDesign.titleFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
                    .multilineTextAlignment(.center)
            }

            // Main content
            VStack(spacing: ResponsiveDesign.spacing(20)) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.accentOrange)
                        .font(ResponsiveDesign.titleFont())

                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                        Text("Hochrisiko-Warnung")
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(AppTheme.fontColor)

                        Text(self.combinedWarningText)
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.8))
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()
                }
                .padding()
                .background(AppTheme.accentOrange.opacity(0.1))
                .cornerRadius(ResponsiveDesign.spacing(12))
                .overlay(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                        .stroke(AppTheme.accentOrange.opacity(0.3), lineWidth: 1)
                )

                // Risk class indicator
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    Text("Ihre Risikoklasse")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))

                    HStack(spacing: ResponsiveDesign.spacing(4)) {
                        ForEach(1...7, id: \.self) { index in
                            Circle()
                                .fill(index <= 7 ? AppTheme.accentRed : Color.gray.opacity(0.3))
                                .frame(width: 12, height: 12)
                        }
                    }

                    Text("Risikoklasse 7 - Sehr hohes Risiko")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)
                }
                .padding()
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(12))

                // Confirmation message
                VStack(spacing: ResponsiveDesign.spacing(12)) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.accentGreen)
                            .font(ResponsiveDesign.titleFont())

                        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                            Text("Registrierung kann fortgesetzt werden")
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.fontColor)

                            Text("Mit Risikoklasse 7 können Sie in der App handeln.")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                                .multilineTextAlignment(.leading)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(AppTheme.accentGreen.opacity(0.1))
                    .cornerRadius(ResponsiveDesign.spacing(12))
                    .overlay(
                        RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                            .stroke(AppTheme.accentGreen.opacity(0.3), lineWidth: 1)
                    )
                }
            }

            Spacer()

            // Complete Registration button
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Button("Complete Registration") {
                    self.coordinator.presentWelcomePage()
                }
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.buttonColor)
                .cornerRadius(ResponsiveDesign.spacing(12))
            }
        }
        .padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())
        .task {
            let provider = LegalSnippetProvider(termsContentService: services.termsContentService)
            let language: TermsOfServiceDataProvider.Language = .german
            async let maxLossTask = provider.text(
                for: .riskClass7MaxLossWarning,
                language: language,
                documentType: .terms,
                defaultText: self.defaultMaxLossWarningText,
                placeholders: [:]
            )
            async let experiencedTask = provider.text(
                for: .riskClass7ExperiencedOnly,
                language: language,
                documentType: .terms,
                defaultText: self.defaultExperiencedOnlyText,
                placeholders: [:]
            )
            let (maxLoss, experienced) = await (maxLossTask, experiencedTask)
            self.maxLossWarningText = maxLoss
            self.experiencedOnlyText = experienced
        }
    }
}

#Preview {
    RiskClass7ConfirmationStep(signUpData: SignUpData(), coordinator: SignUpCoordinator())
        .background(AppTheme.screenBackground)
}
