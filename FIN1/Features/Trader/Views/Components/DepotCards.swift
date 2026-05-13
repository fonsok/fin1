import SwiftUI

struct PositionCard: View {
    let position: MockPosition
    let positionNumber: Int
    @State private var showDetails = false

    var body: some View {
        Button(action: { self.showDetails = true }, label: {
            CardContainer(position: self.positionNumber) {
                // 6 Tiles in 3 Rows using TileGrid
                TileGrid(tiles: self.positionTiles, columns: 2)
            }
        })
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: self.$showDetails) {
            PositionDetailView(position: self.position)
        }
    }

    private var positionTiles: [TileData] {
        [
            // Row 1: Symbol, Company Name
            TileData(title: "Symbol", value: self.position.symbol),
            TileData(title: "Company", value: self.position.companyName),

            // Row 2: Shares, Avg Price
            TileData(title: "Shares", value: "\(self.position.quantity)"),
            TileData(title: "Avg Price", value: "$\(String(format: "%.2f", self.position.averagePrice))"),

            // Row 3: Market Value, Current Price
            TileData(title: "Market Value", value: "$\(String(format: "%.0f", self.position.marketValue))"),
            TileData(title: "Current Price", value: "$\(String(format: "%.2f", self.position.currentPrice))")
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
            Text(self.value)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.accentLightBlue)

            Text(self.title)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)

            Text(self.description)
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
            Image(systemName: self.history.icon)
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                .foregroundColor(AppTheme.accentLightBlue)
                .frame(width: ResponsiveDesign.spacing(24))

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text(self.history.action)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Text(self.history.details)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(4)) {
                Text(
                    self.history.amount > 0 ? "+$\(String(format: "%.0f", self.history.amount))" : "-$\(String(format: "%.0f", abs(self.history.amount)))"
                )
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(self.history.amount > 0 ? AppTheme.accentGreen : AppTheme.accentRed)

                Text(self.history.date.formatted(date: .abbreviated, time: .omitted))
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
            Text(self.value)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)

            Text(self.title)
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
