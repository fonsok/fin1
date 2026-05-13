import SwiftUI

struct RiskClassTestScenariosView: View {
    let onResetToDefaults: () -> Void
    let onTestDerivativesExperience: () -> Void
    let onTestHighRiskProfile: () -> Void
    let onTestMaximumRisk: () -> Void

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Text("Test Scenarios")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                TestScenarioButton(
                    title: "Reset to Defaults (Risk Class 2)",
                    description: "Income: Middle, No experience, 10% return",
                    action: self.onResetToDefaults
                )

                TestScenarioButton(
                    title: "50+ Derivatives Experience (Risk Class 3+)",
                    description: "Add 50+ derivatives transactions",
                    action: self.onTestDerivativesExperience
                )

                TestScenarioButton(
                    title: "High Income + Experience (Risk Class 4+)",
                    description: "High income + derivatives experience",
                    action: self.onTestHighRiskProfile
                )

                TestScenarioButton(
                    title: "Maximum Risk Profile (Risk Class 6)",
                    description: "All high-risk factors",
                    action: self.onTestMaximumRisk
                )
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

struct TestScenarioButton: View {
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: self.action, label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(self.title)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Text(self.description)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(AppTheme.sectionBackground.opacity(0.5))
            .cornerRadius(ResponsiveDesign.spacing(8))
        })
    }
}

#Preview {
    RiskClassTestScenariosView(
        onResetToDefaults: {},
        onTestDerivativesExperience: {},
        onTestHighRiskProfile: {},
        onTestMaximumRisk: {}
    )
    .padding()
    .background(AppTheme.screenBackground)
}
