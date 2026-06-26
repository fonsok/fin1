import SwiftUI

struct RiskClass7ConfirmationStep: View {
    @ObservedObject var signUpData: SignUpData
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

    private var canCompleteRegistration: Bool {
        self.signUpData.hasRequiredLegalConsents
    }

    private var combinedWarningText: String {
        let experienced = self.experiencedOnlyText.isEmpty ? self.defaultExperiencedOnlyText : self.experiencedOnlyText
        let maxLoss = self.maxLossWarningText.isEmpty ? self.defaultMaxLossWarningText : self.maxLossWarningText
        return "Sie haben Risikoklasse 7 ausgewählt. \(experienced) \(maxLoss)"
    }

    var body: some View {
        SignUpStepList {
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
                .signUpListSection(stripeIndex: 0)

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

            self.legalConsentStatusSection
                .signUpListSection(stripeIndex: 1)

            Spacer()

            // Complete Registration button — continues to role-specific agreement (Gate 2)
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                if !self.canCompleteRegistration {
                    Text(
                        "Bitte akzeptieren Sie Nutzungsbedingungen und Datenschutzrichtlinie "
                            + "im Schritt „Contact Information“."
                    )
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentOrange)
                    .multilineTextAlignment(.center)
                }

                Button("Weiter zur Vereinbarung") {
                    self.coordinator.goToStep(.roleAgreement)
                }
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.buttonColor)
                .cornerRadius(ResponsiveDesign.spacing(12))
                .disabled(!self.canCompleteRegistration || self.coordinator.isLoading)
                .accessibilityIdentifier("RiskClass7ContinueToRoleAgreementButton")
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

    private var legalConsentStatusSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Rechtliche Einwilligungen")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            self.legalConsentStatusRow(
                title: "Nutzungsbedingungen",
                accepted: self.signUpData.acceptedTerms
            )
            self.legalConsentStatusRow(
                title: "Datenschutzrichtlinie",
                accepted: self.signUpData.acceptedPrivacyPolicy
            )
        }
    }

    private func legalConsentStatusRow(title: String, accepted: Bool) -> some View {
        HStack(spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: accepted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(accepted ? AppTheme.accentGreen : AppTheme.accentOrange)
            Text(title)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
            Spacer()
        }
    }
}

#Preview {
    RiskClass7ConfirmationStep(signUpData: SignUpData(), coordinator: SignUpCoordinator())
        .background(AppTheme.screenBackground)
}
