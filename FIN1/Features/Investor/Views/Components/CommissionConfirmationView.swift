import SwiftUI

// MARK: - Commission Confirmation View
/// Displays commission confirmation checkbox with trader information
struct CommissionConfirmationView: View {
    let traderUsername: String
    let commissionPercentage: String
    @Binding var isConfirmed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack(alignment: .top, spacing: ResponsiveDesign.spacing(12)) {
                // Checkbox
                Button(action: {
                    isConfirmed.toggle()
                }) {
                    Rectangle()
                        .fill(isConfirmed ? AppTheme.accentGreen : AppTheme.inputFieldBackground)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Group {
                                if isConfirmed {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppTheme.fontColor)
                                        .font(.system(size: 16, weight: .bold))
                                }
                            }
                        )
                }
                .buttonStyle(PlainButtonStyle())

                // Commission text
                Text("Trader \(traderUsername) receives a \(commissionPercentage) commission on the profit.")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: ResponsiveDesign.spacing(16)) {
        CommissionConfirmationView(
            traderUsername: "john_doe",
            commissionPercentage: CalculationConstants.FeeRates.traderCommissionPercentage,
            isConfirmed: .constant(false)
        )

        CommissionConfirmationView(
            traderUsername: "john_doe",
            commissionPercentage: CalculationConstants.FeeRates.traderCommissionPercentage,
            isConfirmed: .constant(true)
        )
    }
    .padding()
    .background(AppTheme.screenBackground)
}
