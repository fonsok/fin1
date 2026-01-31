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
                        TraderDetailHeaderView(trader: trader)

                        // Invest Button positioned before performance insights
                        TraderInvestButton(
                            trader: trader,
                            showInvestSheet: $showInvestmentSheet
                        )

                        // Performance Overview
                        TraderDetailPerformanceView(trader: trader)

                        // Tab Content
                        TraderDetailTabsView(selectedTab: $selectedTab)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Invest") {
                        showInvestmentSheet = true
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
        .sheet(isPresented: $showInvestmentSheet) {
            InvestmentSheet(trader: trader) {
                // Navigate back to investor dashboard
                dismiss()
            }
        }
    }
}

#Preview {
    ModularTraderDetailView(trader: mockTraders[0])
}
