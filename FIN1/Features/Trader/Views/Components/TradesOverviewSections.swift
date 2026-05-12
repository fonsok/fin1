import SwiftUI

// MARK: - Section Components

/// Displays the ongoing trades section
struct OngoingTradesSection: View {
    let ongoingTrades: [TradeOverviewItem]

    var body: some View {
        if ongoingTrades.isEmpty {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Image(systemName: "clock")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2.4))
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))

                Text("Keine laufenden Trades")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                Text("Aktuell sind keine Trades aktiv")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, ResponsiveDesign.spacing(3))
            .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                Text("Laufende Trades")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.accentOrange)

                LazyVStack(spacing: ResponsiveDesign.spacing(12)) {
                    ForEach(ongoingTrades) { trade in
                        OngoingTradeCard(trade: trade)
                    }
                }
            }
        }
    }
}

/// Displays the completed trades section
struct CompletedTradesSection: View {
    let completedTrades: [TradeOverviewItem]
    let tableRows: [TradeTableRowData]
    let columnWidths: ColumnWidths?
    let commissionPercentage: String
    @Binding var selectedTimePeriod: TradeTimePeriod
    @Binding var showCustomizeDetails: Bool
    let onTimePeriodChanged: (TradeTimePeriod) -> Void
    @Environment(\.appServices) private var services

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Abgeschlossene Trades")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            // Header with filter and customization (moved inside this section)
            TradesOverviewHeaderView(
                selectedTimePeriod: $selectedTimePeriod,
                showCustomizeDetails: $showCustomizeDetails,
                onTimePeriodChanged: onTimePeriodChanged
            )

            if completedTrades.isEmpty {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2.4))
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))

                    Text("Keine abgeschlossenen Trades")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))

                    Text("Aktuell sind keine Trades abgeschlossen")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, ResponsiveDesign.spacing(32))
                .frame(maxWidth: .infinity)
            } else {
                if let columnWidths = columnWidths {
                    TradesTable(trades: tableRows, columnWidths: columnWidths, commissionPercentage: commissionPercentage, services: services)
                }
            }
        }
    }
}

/// Card component for displaying ongoing trades
struct OngoingTradeCard: View {
    let trade: TradeOverviewItem
    @Environment(\.appServices) private var services

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Text("Trade #\(trade.tradeNumber)")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Text(trade.statusText)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.accentOrange)
                    .padding(.horizontal, ResponsiveDesign.spacing(8))
                    .padding(.vertical, ResponsiveDesign.spacing(4))
                    .background(AppTheme.accentOrange.opacity(0.2))
                    .cornerRadius(ResponsiveDesign.spacing(8))
            }

            // P&L and ROI removed for ongoing trades since only buy orders are done
            // These metrics are only relevant after sell orders are completed
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
        .onTapGesture {
            trade.onDetailsTapped()
        }
    }

}
