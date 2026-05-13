import SwiftUI

// MARK: - Week Row
/// Displays a single week row in the trader performance table
struct TraderPerformanceWeekRow: View {
    let weekData: WeekTradeData
    let showMonthLabel: Bool

    init(weekData: WeekTradeData, showMonthLabel: Bool = true) {
        self.weekData = weekData
        self.showMonthLabel = showMonthLabel
    }

    var body: some View {
        HStack(alignment: .center, spacing: ResponsiveDesign.spacing(0)) {
            // KW Number Column
            if self.showMonthLabel {
                // Legacy layout with month (not used in grouped view)
                self.legacyMonthLayout
            } else {
                // Column 2: KW number (month is shown separately in Column 1)
                self.weekNumberColumn
            }

            // Column 3: Return Values with Colored Boxes (scrollable)
            self.returnValuesColumn
        }
        .background(AppTheme.sectionBackground)

        // Horizontal separator between rows
        Rectangle()
            .fill(Color.white.opacity(0.6))
            .frame(height: 1)
    }

    // MARK: - Legacy Month Layout
    private var legacyMonthLayout: some View {
        HStack(spacing: ResponsiveDesign.spacing(8)) {
            VStack {
                Text(self.weekData.month)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
                Spacer()
            }
            .frame(width: ResponsiveDesign.spacing(50))

            Text("\(self.weekData.week)")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)
                .frame(width: ResponsiveDesign.spacing(40), alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, ResponsiveDesign.spacing(16))
        .padding(.vertical, ResponsiveDesign.spacing(12))
    }

    // MARK: - Week Number Column
    private var weekNumberColumn: some View {
        Text("\(self.weekData.week)")
            .font(ResponsiveDesign.captionFont())
            .fontWeight(.regular)
            .foregroundColor(AppTheme.fontColor.opacity(0.6))
            .frame(width: ResponsiveDesign.spacing(40), alignment: .center)
            .multilineTextAlignment(.center)
            .frame(minHeight: ResponsiveDesign.spacing(44))
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
    }

    // MARK: - Return Values Column
    private var returnValuesColumn: some View {
        HStack(alignment: .center, spacing: ResponsiveDesign.spacing(8)) {
            ForEach(self.weekData.tradeReturns) { tradeReturn in
                self.returnBox(for: tradeReturn)
            }

            Spacer(minLength: ResponsiveDesign.spacing(200))
        }
        .frame(minHeight: ResponsiveDesign.spacing(44))
        .padding(.leading, ResponsiveDesign.spacing(16))
        .padding(.trailing, ResponsiveDesign.spacing(16))
    }

    // MARK: - Return Box View
    @ViewBuilder
    private func returnBox(for tradeReturn: TradeReturnData) -> some View {
        if tradeReturn.isActive {
            self.activeTradeBox(tradeReturn: tradeReturn)
        } else {
            self.completedTradeBox(tradeReturn: tradeReturn)
        }
    }

    private func activeTradeBox(tradeReturn: TradeReturnData) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(2)) {
            Text("active Trade")
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Text("Nr. \(tradeReturn.tradeNumber)")
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)
        }
        .padding(.horizontal, ResponsiveDesign.spacing(8))
        .padding(.vertical, ResponsiveDesign.spacing(6))
        .frame(minWidth: ResponsiveDesign.spacing(80))
        .background(AppTheme.inputFieldBackground.opacity(0.5))
        .cornerRadius(ResponsiveDesign.spacing(6))
    }

    private func completedTradeBox(tradeReturn: TradeReturnData) -> some View {
        let isPositive = tradeReturn.roi > 0
        let backgroundColor = isPositive ? AppTheme.accentGreen.opacity(0.2) : AppTheme.accentRed.opacity(0.2)
        let textColor = isPositive ? AppTheme.accentGreen : AppTheme.accentRed

        return Text(tradeReturn.roi.formattedAsROIPercentage())
            .font(ResponsiveDesign.bodyFont())
            .fontWeight(.medium)
            .foregroundColor(textColor)
            .padding(.horizontal, ResponsiveDesign.spacing(8))
            .padding(.vertical, ResponsiveDesign.spacing(6))
            .frame(minWidth: ResponsiveDesign.spacing(60))
            .background(backgroundColor)
            .cornerRadius(ResponsiveDesign.spacing(6))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(6))
                    .stroke(textColor.opacity(0.3), lineWidth: 1)
            )
    }
}











