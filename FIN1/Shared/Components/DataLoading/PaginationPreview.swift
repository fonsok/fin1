import SwiftUI

// MARK: - Pagination Preview
/// This file now serves as a preview container for the extracted pagination components.
/// Individual components have been moved to separate files for better organization.

struct PaginationPreview: PreviewProvider {
    static var previews: some View {
        // PaginatedListView Preview
        PaginatedListView(
            config: .small,
            loadFunction: { page, pageSize in
                // Mock data loading
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                return (0..<pageSize).map { index in
                    MockTrader(
                        name: "Trader \(page * pageSize + index)",
                        username: "trader\(page * pageSize + index)",
                        specialization: "Options Trading",
                        experienceYears: Int.random(in: 1...10),
                        isVerified: Bool.random(),
                        performance: Double.random(in: -10...50),
                        totalTrades: Int.random(in: 10...100),
                        winRate: Double.random(in: 0.3...0.9),
                        averageReturn: Double.random(in: -5...15),
                        totalReturn: Double.random(in: -1_000...5_000),
                        riskLevel: .medium,
                        recentTrades: [],
                        lastNTrades: 10,
                        successfulTradesInLastN: Int.random(in: 5...10),
                        averageReturnLastNTrades: Double.random(in: -5...15),
                        consecutiveWinningTrades: Int.random(in: 0...5),
                        maxDrawdown: Double.random(in: 5...25),
                        sharpeRatio: Double.random(in: 0.5...2.5)
                    )
                }
            },
            content: { (trader: MockTrader) in
                Text(trader.name)
                    .padding()
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(8))
            }
        )
        .padding()
        .background(AppTheme.screenBackground)
    }
}
