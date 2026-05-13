import SwiftUI

struct DashboardTraderOverview: View {
    @StateObject private var viewModel: DashboardTraderOverviewViewModel
    @State private var selectedTraderID: TraderIDItem?
    @Environment(\.appServices) private var appServices
    @State private var showError: Bool = false
    @State private var errorTitle: String = ""
    // Observe via onChange on services; no need to hold a concrete ObservedObject here

    init() {
        let tempServices = AppServices.live
        self._viewModel = StateObject(wrappedValue: DashboardTraderOverviewViewModel(
            traderDataService: tempServices.traderDataService,
            watchlistService: tempServices.watchlistService
        ))
    }

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            HStack {
                Text("Top Recent Trades")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.regular)
                    .foregroundColor(AppTheme.fontColor)
                Spacer()

                Button("View All") {
                    // TODO: Navigate to full trades list
                }
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.accentLightBlue)
            }

            // Reusable Data Table
            // Wrap in horizontal scroll to avoid width-driven clipping on smaller devices
            ScrollView(.horizontal, showsIndicators: false) {
                DataTable.traderPerformanceTable(
                    rows: self.viewModel.cachedRows,
                    showTraderColumn: true,
                    isInteractive: false
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(item: self.$selectedTraderID) { traderIDItem in
            TraderNavigationHelper.sheetView(for: traderIDItem.id, appServices: self.appServices)
        }
        .onAppear {
            // Set up trader tap handler
            self.viewModel.onTraderTap = { username in
                if let traderID = viewModel.getTraderID(username: username) {
                    self.selectedTraderID = TraderIDItem(id: traderID)
                }
            }
        }
        .onChange(of: self.appServices.traderDataService.traders.count) { _, _ in
            self.viewModel.updateCachedData()
        }
        .onChange(of: self.appServices.watchlistService.watchlist.count) { _, _ in
            self.viewModel.updateCachedData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("WatchlistUpdated"))) { _ in
            self.viewModel.updateCachedData()
        }
        .onReceive(self.viewModel.$lastWatchlistError.dropFirst().receive(on: RunLoop.main)) { err in
            guard let err else { return }
            self.errorTitle = err
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { self.showError = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.25)) { self.showError = false }
            }
        }
        .watchlistError(isShowing: self.showError, title: self.errorTitle)
    }
}

#Preview {
    DashboardTraderOverview()
}
