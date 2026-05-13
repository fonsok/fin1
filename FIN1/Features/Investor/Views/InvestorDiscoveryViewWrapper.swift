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
        InvestorDiscoveryView(viewModel: self.viewModel, savedFiltersManager: self.savedFiltersManager)
            .task {
                self.viewModel.reconfigure(with: self.services)
                self.viewModel.loadTraders()

                // Register manager with FilterSyncService
                if let filterSyncService = services.filterSyncService as? FilterSyncService {
                    filterSyncService.registerTraderFiltersManager(self.savedFiltersManager)
                }
            }
    }
}
