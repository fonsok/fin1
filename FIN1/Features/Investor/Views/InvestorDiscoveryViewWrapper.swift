import SwiftUI

// MARK: - Environment-injected wrapper for InvestorDiscoveryView
struct InvestorDiscoveryViewWrapper: View {
    @Environment(\.appServices) private var services
    @StateObject private var viewModel: InvestorDiscoveryViewModel
    @StateObject private var savedFiltersManager: SavedFiltersManager

    init() {
        // Create placeholder VM; reconfigure with env services on task
        self._viewModel = StateObject(wrappedValue: InvestorDiscoveryViewModel(
            traderDataService: TraderDataService(),
            filterPersistence: FilterPersistenceRepository()
        ))
        self._savedFiltersManager = StateObject(wrappedValue: SavedFiltersManager())
    }

    var body: some View {
        InvestorDiscoveryView(viewModel: viewModel, savedFiltersManager: savedFiltersManager)
            .task {
                viewModel.reconfigure(with: services)
                viewModel.loadTraders()
            }
    }
}
