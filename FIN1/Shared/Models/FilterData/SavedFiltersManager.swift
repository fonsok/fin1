import Foundation
import SwiftUI

// MARK: - Saved Filters Manager
@MainActor
final class SavedFiltersManager: ObservableObject {
    @Published var savedFilters: [FilterCombination] = []
    private let userDefaults = UserDefaults.standard
    private let savedFiltersKey = "SavedTraderFilters"

    // Backend synchronization dependencies (optional)
    private var filterAPIService: FilterAPIServiceProtocol?
    private var userService: (any UserServiceProtocol)?

    init(
        filterAPIService: FilterAPIServiceProtocol? = nil,
        userService: (any UserServiceProtocol)? = nil
    ) {
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
            await self.loadFromBackend()
        }

        // Fallback to local storage
        if let data = userDefaults.data(forKey: savedFiltersKey),
           let decoded = try? JSONDecoder().decode([FilterCombination].self, from: data) {
            savedFilters = decoded
        }
    }

    private func loadFromBackend() async {
        guard let apiService = filterAPIService,
              let userId = userService?.currentUser?.id else {
            return
        }

        do {
            let backendFilters = try await apiService.fetchTraderFilters(for: userId)
            // Merge backend filters with local (avoid duplicates by name)
            let existingNames = Set(savedFilters.map { $0.name })
            let newFilters = backendFilters.filter { !existingNames.contains($0.name) }
            savedFilters.append(contentsOf: newFilters)
            saveFilters()
        } catch {
            print("⚠️ Failed to load trader filters from backend: \(error.localizedDescription)")
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

    func addFilter(_ filter: FilterCombination) {
        savedFilters.append(filter)
        saveFilters()

        // Sync to backend (write-through pattern)
        if let apiService = filterAPIService,
           let userId = userService?.currentUser?.id {
            Task {
                do {
                    _ = try await apiService.saveTraderFilter(filter, userId: userId)
                    print("✅ Trader filter saved to backend: \(filter.name)")
                } catch {
                    print("⚠️ Failed to sync trader filter to backend: \(error.localizedDescription)")
                }
            }
        }
    }

    func removeFilter(_ filter: FilterCombination) {
        // Allow deletion of default filters - they will be recreated on next app launch
        savedFilters.removeAll { $0.id == filter.id }
        saveFilters()

        // Sync deletion to backend (write-through pattern)
        if let apiService = filterAPIService,
           let userId = userService?.currentUser?.id {
            Task {
                do {
                    try await apiService.deleteFilter(filter.id.uuidString, context: .traderDiscovery, userId: userId)
                    print("✅ Trader filter deleted from backend: \(filter.name)")
                } catch {
                    print("⚠️ Failed to sync trader filter deletion to backend: \(error.localizedDescription)")
                }
            }
        }
    }

    func updateFilter(_ filter: FilterCombination) {
        if let index = savedFilters.firstIndex(where: { $0.id == filter.id }) {
            savedFilters[index] = filter
            saveFilters()

            // Sync update to backend (write-through pattern)
            if let apiService = filterAPIService,
               let userId = userService?.currentUser?.id {
                Task {
                    do {
                        _ = try await apiService.updateTraderFilter(filter, userId: userId)
                        print("✅ Trader filter updated on backend: \(filter.name)")
                    } catch {
                        print("⚠️ Failed to sync trader filter update to backend: \(error.localizedDescription)")
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

        print("📤 Syncing trader filters to backend...")

        // Sync all current filters
        let filtersToSync = savedFilters

        for filter in filtersToSync {
            do {
                _ = try await apiService.saveTraderFilter(filter, userId: userId)
            } catch {
                print("⚠️ Failed to sync trader filter \(filter.name): \(error.localizedDescription)")
            }
        }

        print("✅ Trader filters sync completed")
    }
}

