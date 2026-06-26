import SwiftUI

// Import RiskClass components
// Note: These components are now in the RiskClass subfolder

struct RiskClassificationNoteStep: View {
    let signUpData: SignUpData
    let coordinator: SignUpCoordinator
    @State private var showRiskClassSelection = false

    private var currentRiskClass: RiskClass {
        self.signUpData.finalRiskClass
    }

    private var shouldReturnToLanding: Bool {
        self.signUpData.shouldReturnToLandingAtRiskNote
    }

    private var canProceedWithRegistration: Bool {
        self.currentRiskClass == .riskClass7
    }

    private var canOfferManualRiskClassUpgrade: Bool {
        self.signUpData.canOfferManualRiskClassUpgradeAtRiskNote
    }

    var body: some View {
        SignUpStepList {
            Text("Note on risk classification")
                .font(ResponsiveDesign.titleFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .signUpListSection(stripeIndex: 0)

            if self.canProceedWithRegistration {
                self.approvedRiskClassContent
                    .signUpListSection(stripeIndex: 1, bandTint: AppTheme.accentGreen)
            } else if self.canOfferManualRiskClassUpgrade {
                self.rejectedRiskClassContent(showUpgradeOption: true)
                    .signUpListSection(stripeIndex: 1, bandTint: AppTheme.accentOrange)
            } else {
                self.rejectedRiskClassContent(showUpgradeOption: false)
                    .signUpListSection(stripeIndex: 1, bandTint: AppTheme.accentOrange)
            }

            self.riskClassIndicator
                .signUpListSection(stripeIndex: 2)

            self.actionButtons
                .padding(.horizontal, ResponsiveDesign.mainHorizontalPadding())
                .padding(.vertical, ResponsiveDesign.spacing(20))
        }
        .sheet(isPresented: self.$showRiskClassSelection) {
            RiskClassSelectionView(
                selectedRiskClass: Binding(
                    get: { self.signUpData.userSelectedRiskClass },
                    set: { self.signUpData.userSelectedRiskClass = $0 }
                ),
                calculatedRiskClass: self.signUpData.calculatedRiskClass,
                onRiskClass7Confirmed: {
                    self.coordinator.goToStep(.riskClass7Confirmation)
                }
            )
        }
    }

    private var approvedRiskClassContent: some View {
        HStack(alignment: .top, spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppTheme.accentGreen)
                .font(ResponsiveDesign.titleFont())

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text("Ihre Risikoklasse beträgt \(self.currentRiskClass.shortName).")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                Text("Sie können mit der Registrierung fortfahren.")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)
        }
    }

    private func rejectedRiskClassContent(showUpgradeOption: Bool) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            HStack(alignment: .top, spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppTheme.accentOrange)
                    .font(ResponsiveDesign.titleFont())

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text("Ihre Risikoklasse beträgt \(self.currentRiskClass.shortName).")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)

                    Text(
                        showUpgradeOption
                            ? (
                                self.signUpData.hasUserManuallyIncreasedRiskClass
                                    ? "Für unseren risikoreichen Vermögensaufbau (Verlustrisiko bis zu 100 %) benötigen Sie Risikoklasse 7."
                                    : "Wenn Sie sich trotzdem für unseren risikoreichen Vermögensaufbau entscheiden (Verlustrisiko bis zu 100 %), brauchen Sie Risikoklasse 7."
                            )
                            : "Für Ihr Risikoprofil empfehlen wir Ihnen eine klassische Vermögensverwaltung oder Investmentfonds/Vermögensverwaltung."
                    )
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }

            if showUpgradeOption {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                    if self.signUpData.hasUserManuallyIncreasedRiskClass {
                        HStack(alignment: .top, spacing: ResponsiveDesign.spacing(12)) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(AppTheme.accentLightBlue)
                                .font(ResponsiveDesign.headlineFont())

                            Text(
                                "Sie haben Ihre Risikoklasse selbst erhöht. Bitte wählen Sie Risikoklasse 7, um fortzufahren."
                            )
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.8))
                            .multilineTextAlignment(.leading)
                        }
                    }

                    Button("Hier können Sie Ihre Risikoklasse ändern.") {
                        self.showRiskClassSelection = true
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                    .font(ResponsiveDesign.bodyFont())
                    .underline()
                }
            }
        }
    }

    private var riskClassIndicator: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            Text("Aktuelle Risikoklasse")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            HStack(spacing: ResponsiveDesign.spacing(4)) {
                ForEach(1...7, id: \.self) { index in
                    Circle()
                        .fill(index <= self.currentRiskClass.rawValue ? self.currentRiskClass.color : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                }
            }

            Text(self.currentRiskClass.displayName)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            if self.coordinator.canGoBack {
                Button(action: self.coordinator.previousStep) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.accentLightBlue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                            .stroke(AppTheme.accentLightBlue, lineWidth: 2)
                    )
                }
                .accessibilityIdentifier("RiskClassificationNoteBackButton")
            }

            if self.canProceedWithRegistration {
                Button("Complete Registration") {
                    self.coordinator.goToStep(.riskClass7Confirmation)
                }
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.buttonColor)
                .cornerRadius(ResponsiveDesign.spacing(12))
            } else {
                if self.canOfferManualRiskClassUpgrade {
                    Button("Risikoklasse ändern") {
                        self.showRiskClassSelection = true
                    }
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.accentLightBlue)
                    .cornerRadius(ResponsiveDesign.spacing(12))
                }

                if self.shouldReturnToLanding {
                    Button("Zur Startseite") {
                        self.coordinator.requestReturnToLanding()
                    }
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.accentOrange)
                    .cornerRadius(ResponsiveDesign.spacing(12))
                }
            }
        }
    }
}

#Preview {
    RiskClassificationNoteStep(signUpData: SignUpData(), coordinator: SignUpCoordinator())
        .background(AppTheme.screenBackground)
}
