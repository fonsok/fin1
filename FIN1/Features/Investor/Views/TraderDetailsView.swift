import SwiftUI

struct TraderDetailsView: View {
    let trader: MockTrader
    @State private var showInvestSheet = false
    @State private var selectedTab = 0
    @Environment(\.appServices) private var appServices
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                // Trader Header (Trader identification section)
                TraderHeaderView(trader: trader)

                // Data Table
                TraderDetailsDataTableView(trader: trader)

                investmentPerformanceSection

                // Investment Information (for investors)
                if appServices.userService.currentUser?.role == .investor {
                    TraderInvestmentInformationView(trader: trader)
                }

                // Tab Navigation
                TraderTabNavigationView(selectedTab: $selectedTab)

                // Tab Content
                TraderTabContentView(trader: trader, selectedTab: $selectedTab)
            }
            .padding()
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }, label: {
                    Image(systemName: "chevron.left")
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize(), weight: .medium))
                        .foregroundColor(AppTheme.accentLightBlue)
                })
            }

            ToolbarItem(placement: .principal) {
                Text("Trader Details")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.regular)
                    .foregroundColor(AppTheme.fontColor)
            }
        }
        .sheet(isPresented: $showInvestSheet) {
            InvestmentSheet(trader: trader, onInvestmentSuccess: {
                // Navigate back to investor dashboard
                dismiss()
            })
        }
    }
}

// MARK: - Subviews
private extension TraderDetailsView {
    @ViewBuilder
    var investmentPerformanceSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            TraderInvestButton(trader: trader, showInvestSheet: $showInvestSheet)
            TraderPerformanceSection(trader: trader)
        }
    }
}
