import Foundation

// MARK: - Filter Sync Service Protocol

/// Protocol for synchronizing saved filters to backend
protocol FilterSyncServiceProtocol {
    func syncToBackend() async
}

// MARK: - Filter Sync Service

/// Service that coordinates synchronization of all filter repositories
@MainActor
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
        repository.configure(filterAPIService: self.filterAPIService, userService: self.userService)
    }

    /// Register trader filters manager for sync
    func registerTraderFiltersManager(_ manager: SavedFiltersManager) {
        self.traderFiltersManager = manager
        manager.configure(filterAPIService: self.filterAPIService, userService: self.userService)
    }

    func syncToBackend() async {
        print("📤 Syncing all filters to backend...")

        if let securitiesRepo = securitiesFiltersRepository {
            await securitiesRepo.syncToBackend()
        }
        if let traderManager = traderFiltersManager {
            await traderManager.syncToBackend()
        }

        print("✅ All filters sync completed")
    }
}
