import SwiftUI

// MARK: - Pagination Preview
/// Preview container for pagination components using `InvestorTrader` catalog rows.

struct PaginationPreview: PreviewProvider {
    static var previews: some View {
        PaginatedListView(
            config: .small,
            loadFunction: { page, pageSize in
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return (0..<pageSize).map { index in
                    previewTrader(page: page, pageSize: pageSize, index: index)
                }
            },
            content: { (trader: InvestorTrader) in
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text(trader.name)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                    Text(trader.username)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.tertiaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(8))
            }
        )
        .padding()
        .background(AppTheme.screenBackground)
    }

    private static func previewTrader(page: Int, pageSize: Int, index: Int) -> InvestorTrader {
        let i = page * pageSize + index
        let performance = Double((i % 7)) * 3.5 - 5
        return InvestorTrader(
            catalogId: "preview-trader-\(i)",
            parseUserId: nil,
            name: "Trader \(i)",
            username: "trader\(i)",
            specialization: "Options Trading",
            experienceYears: 5,
            isVerified: true,
            riskLevel: .medium,
            demoMetrics: TraderDemoMetrics(
                performance: performance,
                totalTrades: 50 + i,
                winRate: 60 + Double(i % 20),
                averageReturn: 4.2,
                totalReturn: performance * 100,
                recentTrades: [],
                lastNTrades: 10,
                successfulTradesInLastN: 7,
                averageReturnLastNTrades: 3.1,
                consecutiveWinningTrades: 2,
                maxDrawdown: 8,
                sharpeRatio: 1.4
            ),
            isFromMockCatalog: false
        )
    }
}
