import SwiftUI

// MARK: - Multiple Investments Preview
/// Displays preview for multiple investments
struct MultipleInvestmentsPreview: View {
    let numberOfInvestments: Int
    let amountPerInvestment: Double

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            ForEach(1...min(numberOfInvestments, 3), id: \.self) { investmentNumber in
                HStack {
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                        Text("Investment #\(investmentNumber)")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor)
                        Text(investmentNumber == 1 ? "Next available" : "Future investment")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(4)) {
                        Text(amountPerInvestment.formattedAsLocalizedCurrency())
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.accentGreen)
                        Text("\(amountPerInvestment.formattedAsLocalizedCurrency()) per investment")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    }
                }
                .padding()
                .background(AppTheme.systemSecondaryBackground)
                .cornerRadius(ResponsiveDesign.spacing(12))
            }

            if numberOfInvestments > 3 {
                Text("+ \(numberOfInvestments - 3) more investment\(numberOfInvestments - 3 == 1 ? "" : "s")")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .padding(.top, ResponsiveDesign.spacing(4))
            }
        }
    }
}

// MARK: - Preview
#Preview {
    MultipleInvestmentsPreview(numberOfInvestments: 5, amountPerInvestment: 200.00)
        .padding()
        .background(AppTheme.screenBackground)
}
