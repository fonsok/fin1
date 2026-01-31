import Foundation
import SwiftUI

// MARK: - Saved Filters Manager
final class SavedFiltersManager: ObservableObject {
    @Published var savedFilters: [FilterCombination] = []
    private let userDefaults = UserDefaults.standard
    private let savedFiltersKey = "SavedTraderFilters"

    init() {
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

    private func loadSavedFilters() {
        if let data = userDefaults.data(forKey: savedFiltersKey),
           let decoded = try? JSONDecoder().decode([FilterCombination].self, from: data) {
            savedFilters = decoded
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
    }

    func removeFilter(_ filter: FilterCombination) {
        // Allow deletion of default filters - they will be recreated on next app launch
        savedFilters.removeAll { $0.id == filter.id }
        saveFilters()
    }

    func updateFilter(_ filter: FilterCombination) {
        if let index = savedFilters.firstIndex(where: { $0.id == filter.id }) {
            savedFilters[index] = filter
            saveFilters()
        }
    }
}

