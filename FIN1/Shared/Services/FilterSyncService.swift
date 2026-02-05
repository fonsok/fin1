import Foundation

// MARK: - Filter Sync Service Protocol

/// Protocol for synchronizing saved filters to backend
protocol FilterSyncServiceProtocol {
    func syncToBackend() async
}

// MARK: - Filter Sync Service

/// Service that coordinates synchronization of all filter repositories
final class FilterSyncService: FilterSyncServiceProtocol {
    private let filterAPIService: FilterAPIServiceProtocol
    private let userService: any UserServiceProtocol

    // Repositories to sync (injected)
    private var securitiesFiltersRepository: SavedSecuritiesFiltersRepository?
    private var traderFiltersManager: SavedFiltersManager?

    init(
        filterAPIService: FilterAPIServiceProtocol,
        userService: any UserServiceProtocol
    ) {
        self.filterAPIService = filterAPIService
        self.userService = userService
    }

    /// Register securities filters repository for sync
    func registerSecuritiesFiltersRepository(_ repository: SavedSecuritiesFiltersRepository) {
        self.securitiesFiltersRepository = repository
        repository.configure(filterAPIService: filterAPIService, userService: userService)
    }

    /// Register trader filters manager for sync
    func registerTraderFiltersManager(_ manager: SavedFiltersManager) {
        self.traderFiltersManager = manager
        manager.configure(filterAPIService: filterAPIService, userService: userService)
    }

    func syncToBackend() async {
        print("📤 Syncing all filters to backend...")

        // Sync both repositories in parallel
        async let securitiesSync: () = securitiesFiltersRepository?.syncToBackend() ?? Task {}.value
        async let traderSync: () = traderFiltersManager?.syncToBackend() ?? Task {}.value

        _ = await (securitiesSync, traderSync)

        print("✅ All filters sync completed")
    }
}
