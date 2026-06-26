import SwiftUI

struct ModularTraderDetailView: View {
    let trader: InvestorTrader
    @Environment(\.appServices) private var appServices
    @Environment(\.dismiss) private var dismiss
    @State private var showInvestmentSheet = false
    @State private var selectedTab = 0

    private var canCreatePlatformInvestments: Bool {
        self.appServices.userService.currentUser?.canCreatePlatformInvestments ?? false
    }

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
                        guard self.canCreatePlatformInvestments else { return }
                        self.showInvestmentSheet = true
                    }
                    .foregroundColor(AppTheme.screenBackground)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        self.canCreatePlatformInvestments
                            ? AppTheme.accentLightBlue
                            : AppTheme.fontColor.opacity(0.35)
                    )
                    .cornerRadius(ResponsiveDesign.spacing(8))
                    .disabled(!self.canCreatePlatformInvestments)
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
    ModularTraderDetailView(trader: InvestorTrader(mock: mockTraders[0]))
}
