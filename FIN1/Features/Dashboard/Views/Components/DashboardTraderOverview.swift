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
                    rows: viewModel.cachedRows,
                    showTraderColumn: true,
                    isInteractive: false
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(item: $selectedTraderID) { traderIDItem in
            TraderNavigationHelper.sheetView(for: traderIDItem.id, appServices: appServices)
        }
        .onAppear {
            // Set up trader tap handler
            viewModel.onTraderTap = { username in
                if let traderID = viewModel.getTraderID(username: username) {
                    selectedTraderID = TraderIDItem(id: traderID)
                }
            }
        }
        .onChange(of: appServices.traderDataService.traders.count) { _, _ in
            viewModel.updateCachedData()
        }
        .onChange(of: appServices.watchlistService.watchlist.count) { _, _ in
            viewModel.updateCachedData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("WatchlistUpdated"))) { _ in
            viewModel.updateCachedData()
        }
        .onReceive(viewModel.$lastWatchlistError.dropFirst().receive(on: RunLoop.main)) { err in
            guard let err else { return }
            errorTitle = err
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { showError = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.25)) { showError = false }
            }
        }
        .watchlistError(isShowing: showError, title: errorTitle)
    }
}

#Preview {
    DashboardTraderOverview()
}
