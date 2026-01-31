import SwiftUI

struct TraderDetailTabsView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            // Tab Picker
            Picker("", selection: $selectedTab) {
                Text("Trading History").tag(0)
                Text("Risk Analysis").tag(1)
                Text("Reviews").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Tab Content
            switch selectedTab {
            case 0:
                TraderDetailTradingHistoryTab()
            case 1:
                TraderDetailRiskAnalysisTab()
            case 2:
                TraderDetailReviewsTab()
            default:
                EmptyView()
            }
        }
    }
}

#Preview {
    TraderDetailTabsView(selectedTab: .constant(0))
        .padding()
        .background(AppTheme.screenBackground)
}
