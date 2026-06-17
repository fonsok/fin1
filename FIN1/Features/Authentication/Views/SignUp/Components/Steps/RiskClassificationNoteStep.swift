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
        [.riskClass5, .riskClass6].contains(self.currentRiskClass) && !self.shouldReturnToLanding
    }

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(24)) {
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                Text("Note on risk classification")
                    .font(ResponsiveDesign.titleFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
                    .multilineTextAlignment(.center)
            }

            if self.canProceedWithRegistration {
                self.approvedRiskClassContent
            } else if self.shouldReturnToLanding {
                self.rejectedRiskClassContent(showUpgradeOption: false)
            } else {
                self.rejectedRiskClassContent(showUpgradeOption: true)
            }

            self.riskClassIndicator

            Spacer()

            self.actionButtons
        }
        .padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())
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
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            HStack {
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

    private func rejectedRiskClassContent(showUpgradeOption: Bool) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppTheme.accentOrange)
                    .font(ResponsiveDesign.titleFont())

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text("Ihre Risikoklasse beträgt \(self.currentRiskClass.shortName).")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)

                    Text(
                        showUpgradeOption
                            ? "Für unseren risikoreichen Vermögensaufbau (Verlustrisiko bis zu 100 %) benötigen Sie Risikoklasse 7."
                            : "Für Ihr Risikoprofil empfehlen wir Ihnen eine klassische Vermögensverwaltung oder Investmentfonds/Vermögensverwaltung."
                    )
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

            if showUpgradeOption {
                VStack(spacing: ResponsiveDesign.spacing(12)) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(AppTheme.accentLightBlue)
                            .font(ResponsiveDesign.headlineFont())

                        Text(
                            "Sie haben Ihre Risikoklasse selbst erhöht. Bitte wählen Sie Risikoklasse 7, um fortzufahren."
                        )
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.8))
                        .multilineTextAlignment(.leading)

                        Spacer()
                    }

                    Button("Hier können Sie Ihre Risikoklasse ändern.") {
                        self.showRiskClassSelection = true
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                    .font(ResponsiveDesign.bodyFont())
                    .underline()
                }
                .padding()
                .background(AppTheme.accentLightBlue.opacity(0.1))
                .cornerRadius(ResponsiveDesign.spacing(12))
                .overlay(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                        .stroke(AppTheme.accentLightBlue.opacity(0.3), lineWidth: 1)
                )
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
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
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
            } else if self.shouldReturnToLanding {
                Button("Zur Startseite") {
                    self.coordinator.requestReturnToLanding()
                }
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.accentOrange)
                .cornerRadius(ResponsiveDesign.spacing(12))
            } else if self.canOfferManualRiskClassUpgrade {
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
        }
    }
}

#Preview {
    RiskClassificationNoteStep(signUpData: SignUpData(), coordinator: SignUpCoordinator())
        .background(AppTheme.screenBackground)
}
