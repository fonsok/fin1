import SwiftUI

struct PositionCard: View {
    let position: MockPosition
    let positionNumber: Int
    @State private var showDetails = false

    var body: some View {
        Button(action: { showDetails = true }, label: {
            CardContainer(position: positionNumber) {
                // 6 Tiles in 3 Rows using TileGrid
                TileGrid(tiles: positionTiles, columns: 2)
            }
        })
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showDetails) {
            PositionDetailView(position: position)
        }
    }

    private var positionTiles: [TileData] {
        [
            // Row 1: Symbol, Company Name
            TileData(title: "Symbol", value: position.symbol),
            TileData(title: "Company", value: position.companyName),

            // Row 2: Shares, Avg Price
            TileData(title: "Shares", value: "\(position.quantity)"),
            TileData(title: "Avg Price", value: "$\(String(format: "%.2f", position.averagePrice))"),

            // Row 3: Market Value, Current Price
            TileData(title: "Market Value", value: "$\(String(format: "%.0f", position.marketValue))"),
            TileData(title: "Current Price", value: "$\(String(format: "%.2f", position.currentPrice))")
        ]
    }
}

struct PerformanceMetricCard: View {
    let title: String
    let value: String
    let description: String
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Text(value)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.accentLightBlue)

            Text(title)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)

            Text(description)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

struct DepotHistoryCard: View {
    let history: MockDepotHistory
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: history.icon)
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                .foregroundColor(AppTheme.accentLightBlue)
                .frame(width: ResponsiveDesign.spacing(24))

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text(history.action)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Text(history.details)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(4)) {
                Text(history.amount > 0 ? "+$\(String(format: "%.0f", history.amount))" : "-$\(String(format: "%.0f", abs(history.amount)))")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(history.amount > 0 ? AppTheme.accentGreen : AppTheme.accentRed)

                Text(history.date.formatted(date: .abbreviated, time: .omitted))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.tertiaryText)
            }
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

struct PositionDetailItem: View {
    let title: String
    let value: String
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(4)) {
            Text(value)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)

            Text(title)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: ResponsiveDesign.spacing(16)) {
        PositionCard(position: mockPositions[0], positionNumber: 1)
        PerformanceMetricCard(
            title: "Sharpe Ratio",
            value: "1.24",
            description: "Risk-adjusted return"
        )
        DepotHistoryCard(history: mockDepotHistory[0])
    }
    .padding()
    .background(AppTheme.screenBackground)
}
