import SwiftUI

// MARK: - Investments Time Period Header View
/// Header section with time period filter for completed investments
struct InvestmentsTimePeriodHeaderView: View {
    @Binding var selectedTimePeriod: InvestmentTimePeriod
    let onTimePeriodChanged: (InvestmentTimePeriod) -> Void

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            HStack {
                // Time period filter
                self.timePeriodFilter

                Spacer()
            }
            .padding(.horizontal, ResponsiveDesign.spacing(16))
            .padding(.top, ResponsiveDesign.spacing(8))
            .padding(.bottom, ResponsiveDesign.spacing(24))
        }
        .background(AppTheme.sectionBackground)
    }

    // MARK: - Time Period Filter

    private var timePeriodFilter: some View {
        HStack {
            Text("Zeitraum:")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)

            Menu {
                ForEach(InvestmentTimePeriod.allCases, id: \.self) { period in
                    Button(period.displayName) {
                        self.selectedTimePeriod = period
                        self.onTimePeriodChanged(period)
                    }
                }
            } label: {
                HStack {
                    Text(self.selectedTimePeriod.displayName)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.accentOrange)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentOrange)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    InvestmentsTimePeriodHeaderView(
        selectedTimePeriod: .constant(.last30Days),
        onTimePeriodChanged: { _ in }
    )
    .background(AppTheme.screenBackground)
}











