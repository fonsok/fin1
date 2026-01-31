import SwiftUI

// MARK: - Investment Action Buttons View
/// Displays action buttons for creating investment and canceling
struct InvestmentActionButtonsView: View {
    let canProceed: Bool
    let isLoading: Bool
    let onCreateInvestment: () -> Void
    let onCancel: () -> Void
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            // Create Investment Button
            Button(action: onCreateInvestment, label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Create chargeable Investment")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canProceed ? AppTheme.buttonColor : AppTheme.fontColor.opacity(0.3))
                .foregroundColor(AppTheme.fontColor)
                .cornerRadius(ResponsiveDesign.spacing(12))
            })
            .disabled(!canProceed || isLoading)
            .accessibilityIdentifier("CreateInvestmentButton")

            // Cancel Button
            Button("Cancel") {
                onCancel()
            }
            .foregroundColor(AppTheme.secondaryText)
        }
    }
}

// MARK: - Preview
#Preview {
    InvestmentActionButtonsView(
        canProceed: true,
        isLoading: false,
        onCreateInvestment: {},
        onCancel: {}
    )
    .padding()
    .background(AppTheme.screenBackground)
}
