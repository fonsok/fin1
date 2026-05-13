import SwiftUI

struct ModularRiskClassTest: View {
    @StateObject private var viewModel: RiskClassTestViewModel
    @State private var showingCalculationBreakdown = false

    init() {
        self._viewModel = StateObject(wrappedValue: RiskClassTestViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(20)) {
                Text("Risk Class Test")
                    .font(ResponsiveDesign.titleFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)

                // Current Risk Class Display
                RiskClassCurrentDisplayView(
                    signUpData: self.viewModel.signUpData,
                    calculateCurrentScore: self.viewModel.calculateCurrentScore
                )

                // Test Scenarios
                RiskClassTestScenariosView(
                    onResetToDefaults: self.viewModel.resetToDefaults,
                    onTestDerivativesExperience: self.viewModel.testDerivativesExperience,
                    onTestHighRiskProfile: self.viewModel.testHighRiskProfile,
                    onTestMaximumRisk: self.viewModel.testMaximumRisk
                )

                // Calculation Breakdown
                Button(action: { self.showingCalculationBreakdown.toggle() }, label: {
                    HStack {
                        Text("Show Calculation Breakdown")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)

                        Spacer()

                        Image(systemName: self.showingCalculationBreakdown ? "chevron.up" : "chevron.down")
                            .foregroundColor(AppTheme.fontColor)
                    }
                    .padding()
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(8))
                })

                if self.showingCalculationBreakdown {
                    RiskClassCalculationBreakdownView(signUpData: self.viewModel.signUpData)
                }
            }
            .padding()
        }
        .background(AppTheme.screenBackground)
    }
}

#Preview {
    ModularRiskClassTest()
}
