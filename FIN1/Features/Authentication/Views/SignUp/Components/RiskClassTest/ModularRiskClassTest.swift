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
                    signUpData: viewModel.signUpData,
                    calculateCurrentScore: viewModel.calculateCurrentScore
                )

                // Test Scenarios
                RiskClassTestScenariosView(
                    onResetToDefaults: viewModel.resetToDefaults,
                    onTestDerivativesExperience: viewModel.testDerivativesExperience,
                    onTestHighRiskProfile: viewModel.testHighRiskProfile,
                    onTestMaximumRisk: viewModel.testMaximumRisk
                )

                // Calculation Breakdown
                Button(action: { showingCalculationBreakdown.toggle() }, label: {
                    HStack {
                        Text("Show Calculation Breakdown")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)

                        Spacer()

                        Image(systemName: showingCalculationBreakdown ? "chevron.up" : "chevron.down")
                            .foregroundColor(AppTheme.fontColor)
                    }
                    .padding()
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(8))
                })

                if showingCalculationBreakdown {
                    RiskClassCalculationBreakdownView(signUpData: viewModel.signUpData)
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
