import Foundation
import Combine

// MARK: - Saved Securities Filters Repository
/// Repository for managing saved securities search filter combinations with persistence
final class SavedSecuritiesFiltersRepository: ObservableObject {
    @Published var savedFilters: [SecuritiesFilterCombination] = []
    private let userDefaults: UserDefaults
    private let savedFiltersKey = "SavedSecuritiesFilters"

    // Backend synchronization dependencies (optional)
    private var filterAPIService: FilterAPIServiceProtocol?
    private var userService: (any UserServiceProtocol)?

    init(
        userDefaults: UserDefaults = .standard,
        filterAPIService: FilterAPIServiceProtocol? = nil,
        userService: (any UserServiceProtocol)? = nil
    ) {
        self.userDefaults = userDefaults
        self.filterAPIService = filterAPIService
        self.userService = userService
        loadSavedFilters()
        // Purge any previously persisted default combinations
        let hadDefaults = savedFilters.contains { $0.isDefault }
        if hadDefaults {
            savedFilters.removeAll { $0.isDefault }
            saveFilters()
        }
        // Do not seed defaults anymore
        createDefaultFilters()
    }

    /// Configure backend dependencies (called after initialization)
    func configure(filterAPIService: FilterAPIServiceProtocol, userService: (any UserServiceProtocol)) {
        self.filterAPIService = filterAPIService
        self.userService = userService
    }

    func loadSavedFilters() {
        // Try to load from backend first
        Task {
            await loadFromBackend()
        }

        // Fallback to local storage
        if let data = userDefaults.data(forKey: savedFiltersKey),
           let decoded = try? JSONDecoder().decode([SecuritiesFilterCombination].self, from: data) {
            savedFilters = decoded
        }
    }

    private func loadFromBackend() async {
        guard let apiService = filterAPIService,
              let userId = userService?.currentUser?.id else {
            return
        }

        do {
            let backendFilters = try await apiService.fetchSecuritiesFilters(for: userId)
            await MainActor.run {
                // Merge backend filters with local (avoid duplicates by name)
                let existingNames = Set(savedFilters.map { $0.name })
                let newFilters = backendFilters.filter { !existingNames.contains($0.name) }
                savedFilters.append(contentsOf: newFilters)
                saveFilters()
            }
        } catch {
            print("⚠️ Failed to load filters from backend: \(error.localizedDescription)")
        }
    }

    private func saveFilters() {
        if let encoded = try? JSONEncoder().encode(savedFilters) {
            userDefaults.set(encoded, forKey: savedFiltersKey)
        }
    }

    private func createDefaultFilters() {
        // Intentionally left blank: no seeding of default saved filter combinations
    }

    func addFilter(_ filter: SecuritiesFilterCombination) {
        savedFilters.append(filter)
        saveFilters()

        // Sync to backend (write-through pattern)
        if let apiService = filterAPIService,
           let userId = userService?.currentUser?.id {
            Task.detached { [apiService, filter, userId] in
                do {
                    _ = try await apiService.saveSecuritiesFilter(filter, userId: userId)
                    print("✅ Filter saved to backend: \(filter.name)")
                } catch {
                    print("⚠️ Failed to sync filter to backend: \(error.localizedDescription)")
                }
            }
        }
    }

    func removeFilter(_ filter: SecuritiesFilterCombination) {
        // Allow deletion of default filters - they will be recreated on next app launch
        savedFilters.removeAll { $0.id == filter.id }
        saveFilters()

        // Sync deletion to backend (write-through pattern)
        if let apiService = filterAPIService,
           let userId = userService?.currentUser?.id {
            Task.detached { [apiService, filter, userId] in
                do {
                    // Note: We need objectId to delete, but filter uses UUID
                    // For now, we'll try to delete by name (inefficient but works)
                    // TODO: Store objectId in filter model
                    try await apiService.deleteFilter(filter.id.uuidString, context: .securitiesSearch, userId: userId)
                    print("✅ Filter deleted from backend: \(filter.name)")
                } catch {
                    print("⚠️ Failed to sync filter deletion to backend: \(error.localizedDescription)")
                }
            }
        }
    }

    func updateFilter(_ filter: SecuritiesFilterCombination) {
        if let index = savedFilters.firstIndex(where: { $0.id == filter.id }) {
            savedFilters[index] = filter
            saveFilters()

            // Sync update to backend (write-through pattern)
            if let apiService = filterAPIService,
               let userId = userService?.currentUser?.id {
                Task.detached { [apiService, filter, userId] in
                    do {
                        _ = try await apiService.updateSecuritiesFilter(filter, userId: userId)
                        print("✅ Filter updated on backend: \(filter.name)")
                    } catch {
                        print("⚠️ Failed to sync filter update to backend: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - Backend Synchronization

    func syncToBackend() async {
        guard let apiService = filterAPIService,
              let userId = userService?.currentUser?.id else {
            print("⚠️ FilterAPIService or userId not available for sync")
            return
        }

        print("📤 Syncing securities filters to backend...")

        // Sync all current filters
        let filtersToSync = await MainActor.run { savedFilters }

        for filter in filtersToSync {
            do {
                _ = try await apiService.saveSecuritiesFilter(filter, userId: userId)
            } catch {
                print("⚠️ Failed to sync filter \(filter.name): \(error.localizedDescription)")
            }
        }

        print("✅ Securities filters sync completed")
    }
}
