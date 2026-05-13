import SwiftUI

struct ModularTraderDetailView: View {
    let trader: MockTrader
    @Environment(\.dismiss) private var dismiss
    @State private var showInvestmentSheet = false
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(24)) {
                        // Header Section
                        TraderDetailHeaderView(trader: self.trader)

                        // Invest Button positioned before performance insights
                        TraderInvestButton(
                            trader: self.trader,
                            showInvestSheet: self.$showInvestmentSheet
                        )

                        // Performance Overview
                        TraderDetailPerformanceView(trader: self.trader)

                        // Tab Content
                        TraderDetailTabsView(selectedTab: self.$selectedTab)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        self.dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Invest") {
                        self.showInvestmentSheet = true
                    }
                    .foregroundColor(AppTheme.screenBackground)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.accentLightBlue)
                    .cornerRadius(ResponsiveDesign.spacing(8))
                    .accessibilityIdentifier("InvestButton")
                }
            }
        }
        .sheet(isPresented: self.$showInvestmentSheet) {
            InvestmentSheet(trader: self.trader) {
                // Navigate back to investor dashboard
                self.dismiss()
            }
        }
    }
}

#Preview {
    ModularTraderDetailView(trader: mockTraders[0])
}
