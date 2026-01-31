import SwiftUI

// MARK: - Trades Overview Header View
/// Header section with time period filter and customization options
struct TradesOverviewHeaderView: View {
    @Binding var selectedTimePeriod: TradeTimePeriod
    @Binding var showCustomizeDetails: Bool
    let onTimePeriodChanged: (TradeTimePeriod) -> Void
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            HStack {
                // Time period filter
                timePeriodFilter

                Spacer()

                // Customize details button
                customizeDetailsButton
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
                ForEach(TradeTimePeriod.allCases, id: \.self) { period in
                    Button(period.displayName) {
                        selectedTimePeriod = period
                        onTimePeriodChanged(period)
                    }
                }
            } label: {
                HStack {
                    Text(selectedTimePeriod.displayName)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.accentOrange)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentOrange)
                }
            }
        }
    }

    // MARK: - Customize Details Button

    private var customizeDetailsButton: some View {
        Button(action: {
            showCustomizeDetails = true
        }, label: {
            HStack(spacing: ResponsiveDesign.spacing(4)) {
                Text("weitere Details hinzufügen")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentLightBlue)

                Image(systemName: "pencil")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentLightBlue)
            }
        })
    }
}

// MARK: - Preview

#Preview {
    TradesOverviewHeaderView(
        selectedTimePeriod: .constant(.last30Days),
        showCustomizeDetails: .constant(false),
        onTimePeriodChanged: { _ in }
    )
    .background(AppTheme.screenBackground)
}
