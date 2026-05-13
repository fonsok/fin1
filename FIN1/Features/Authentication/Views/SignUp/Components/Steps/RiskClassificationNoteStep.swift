import SwiftUI

// Import RiskClass components
// Note: These components are now in the RiskClass subfolder

struct RiskClassificationNoteStep: View {
    let signUpData: SignUpData
    let coordinator: SignUpCoordinator
    @State private var showRiskClassSelection = false

    // Ensure the view is reactive to finalRiskClass changes
    private var currentRiskClass: RiskClass {
        return self.signUpData.finalRiskClass
    }

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(24)) {
            // Header
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                Text("Note on risk classification")
                    .font(ResponsiveDesign.titleFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
                    .multilineTextAlignment(.center)
            }

            // Main content based on risk class
            if self.currentRiskClass == .riskClass7 {
                // Risk Class 7 - User can proceed
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
            } else {
                // Risk Classes 1-6 - User is rejected
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
                                "Für Ihr Risikoprofil empfeh-\nlen wir Ihnen eine klassische Vermögensverwaltung oder  Investmentfond/Vermögensverwaltung XYZ"
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

                    // Additional information for risk classes 4, 5, or 6
                    if [.riskClass4, .riskClass5, .riskClass6].contains(self.currentRiskClass) {
                        VStack(spacing: ResponsiveDesign.spacing(12)) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(AppTheme.accentLightBlue)
                                    .font(ResponsiveDesign.headlineFont())

                                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                                    Text(
                                        "Wenn Sie sich trotzdem für unseren risikoreichen Vermögensaufbau entscheiden (Verlustrisiko bis zu 100 %), brauchen Sie Risikoklasse 7."
                                    )
                                    .font(ResponsiveDesign.bodyFont())
                                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                                    .multilineTextAlignment(.leading)
                                }

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

                // Risk class indicator
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

            Spacer()

            // Action buttons based on risk class
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                if self.currentRiskClass == .riskClass7 {
                    // Risk Class 7 - Complete Registration button
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
                    // Risk Classes 1-6 - Back to Startpage button
                    Button("Back to Startpage") {
                        // Request dismissal via the coordinator to return to LandingView
                        self.coordinator.requestDismissal()
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
        .padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())
        .sheet(isPresented: self.$showRiskClassSelection) {
            RiskClassSelectionView(
                selectedRiskClass: Binding(
                    get: { self.signUpData.userSelectedRiskClass },
                    set: { self.signUpData.userSelectedRiskClass = $0 }
                ),
                calculatedRiskClass: self.signUpData.calculatedRiskClass,
                onRiskClass7Confirmed: {
                    // Navigate to Risk Class 7 confirmation page when Risk Class 7 is confirmed
                    self.coordinator.goToStep(.riskClass7Confirmation)
                }
            )
        }
        // Note: Welcome page is now handled by SignUpView for Risk Class 7 users
    }
}

#Preview {
    RiskClassificationNoteStep(signUpData: SignUpData(), coordinator: SignUpCoordinator())
        .background(AppTheme.screenBackground)
}
