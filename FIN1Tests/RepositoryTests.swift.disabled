import XCTest
@testable import FIN1

// MARK: - Repository Tests (In-Memory)
/// Tests for repositories using in-memory UserDefaults for fast, realistic testing

final class RepositoryTests: XCTestCase {

    // MARK: - FilterPersistenceRepository Tests

    func testFilterPersistenceRepository_SetAndGet() {
        // Given - In-memory UserDefaults (unique suite per test)
        guard let userDefaults = UserDefaults(suiteName: UUID().uuidString) else {
            XCTFail("Failed to create in-memory UserDefaults")
            return
        }
        let repository = FilterPersistenceRepository(userDefaults: userDefaults)

        // When
        repository.setAppliedFilterID("test-filter-id")

        // Then
        XCTAssertEqual(repository.getAppliedFilterID(), "test-filter-id")
    }

    func testFilterPersistenceRepository_Clear() {
        // Given
        guard let userDefaults = UserDefaults(suiteName: UUID().uuidString) else {
            XCTFail("Failed to create in-memory UserDefaults")
            return
        }
        let repository = FilterPersistenceRepository(userDefaults: userDefaults)
        repository.setAppliedFilterID("test-filter-id")

        // When
        repository.clearAppliedFilterID()

        // Then
        XCTAssertNil(repository.getAppliedFilterID())
    }

    func testFilterPersistenceRepository_Update() {
        // Given
        guard let userDefaults = UserDefaults(suiteName: UUID().uuidString) else {
            XCTFail("Failed to create in-memory UserDefaults")
            return
        }
        let repository = FilterPersistenceRepository(userDefaults: userDefaults)
        repository.setAppliedFilterID("first-id")

        // When
        repository.setAppliedFilterID("second-id")

        // Then
        XCTAssertEqual(repository.getAppliedFilterID(), "second-id")
    }

    func testFilterPersistenceRepository_Persistence() {
        // Given
        guard let userDefaults = UserDefaults(suiteName: UUID().uuidString) else {
            XCTFail("Failed to create in-memory UserDefaults")
            return
        }
        let repository1 = FilterPersistenceRepository(userDefaults: userDefaults)
        repository1.setAppliedFilterID("persisted-id")

        // When - Create new repository instance (simulates app restart)
        let repository2 = FilterPersistenceRepository(userDefaults: userDefaults)

        // Then - Data should persist
        XCTAssertEqual(repository2.getAppliedFilterID(), "persisted-id")
    }

    func testFilterPersistenceRepository_Isolation() {
        // Given - Two separate in-memory UserDefaults
        guard let userDefaults1 = UserDefaults(suiteName: UUID().uuidString),
              let userDefaults2 = UserDefaults(suiteName: UUID().uuidString) else {
            XCTFail("Failed to create in-memory UserDefaults")
            return
        }
        let repository1 = FilterPersistenceRepository(userDefaults: userDefaults1)
        let repository2 = FilterPersistenceRepository(userDefaults: userDefaults2)

        // When
        repository1.setAppliedFilterID("id-1")
        repository2.setAppliedFilterID("id-2")

        // Then - Each repository should have its own isolated data
        XCTAssertEqual(repository1.getAppliedFilterID(), "id-1")
        XCTAssertEqual(repository2.getAppliedFilterID(), "id-2")
    }

    // MARK: - SavedSecuritiesFiltersRepository Tests

    func testSavedSecuritiesFiltersRepository_AddFilter() {
        // Given
        guard let userDefaults = UserDefaults(suiteName: UUID().uuidString) else {
            XCTFail("Failed to create in-memory UserDefaults")
            return
        }
        let repository = SavedSecuritiesFiltersRepository(userDefaults: userDefaults)
        let filter = createSampleSecuritiesFilter()

        // When
        repository.addFilter(filter)

        // Then
        XCTAssertEqual(repository.savedFilters.count, 1)
        XCTAssertEqual(repository.savedFilters.first?.id, filter.id)
    }

    func testSavedSecuritiesFiltersRepository_RemoveFilter() {
        // Given
        guard let userDefaults = UserDefaults(suiteName: UUID().uuidString) else {
            XCTFail("Failed to create in-memory UserDefaults")
            return
        }
        let repository = SavedSecuritiesFiltersRepository(userDefaults: userDefaults)
        let filter = createSampleSecuritiesFilter()
        repository.addFilter(filter)

        // When
        repository.removeFilter(filter)

        // Then
        XCTAssertEqual(repository.savedFilters.count, 0)
    }

    func testSavedSecuritiesFiltersRepository_UpdateFilter() {
        // Given
        guard let userDefaults = UserDefaults(suiteName: UUID().uuidString) else {
            XCTFail("Failed to create in-memory UserDefaults")
            return
        }
        let repository = SavedSecuritiesFiltersRepository(userDefaults: userDefaults)
        var filter = createSampleSecuritiesFilter()
        repository.addFilter(filter)

        // When - Replace filter by removing and adding a new one with updated name
        repository.removeFilter(filter)
        let updatedFilter = SecuritiesFilterCombination(
            name: "Updated Filter Name",
            filters: filter.filters,
            isDefault: filter.isDefault
        )
        repository.addFilter(updatedFilter)

        // Then
        XCTAssertEqual(repository.savedFilters.count, 1)
        XCTAssertEqual(repository.savedFilters.first?.name, "Updated Filter Name")
    }

    func testSavedSecuritiesFiltersRepository_Persistence() {
        // Given
        guard let userDefaults = UserDefaults(suiteName: UUID().uuidString) else {
            XCTFail("Failed to create in-memory UserDefaults")
            return
        }
        let repository1 = SavedSecuritiesFiltersRepository(userDefaults: userDefaults)
        let filter = createSampleSecuritiesFilter()
        repository1.addFilter(filter)

        // When - Create new repository instance (simulates app restart)
        let repository2 = SavedSecuritiesFiltersRepository(userDefaults: userDefaults)

        // Then - Data should persist
        XCTAssertEqual(repository2.savedFilters.count, 1)
        XCTAssertEqual(repository2.savedFilters.first?.id, filter.id)
    }

    func testSavedSecuritiesFiltersRepository_MultipleFilters() {
        // Given
        guard let userDefaults = UserDefaults(suiteName: UUID().uuidString) else {
            XCTFail("Failed to create in-memory UserDefaults")
            return
        }
        let repository = SavedSecuritiesFiltersRepository(userDefaults: userDefaults)
        let filter1 = createSampleSecuritiesFilter(name: "Filter 1")
        let filter2 = createSampleSecuritiesFilter(name: "Filter 2")
        let filter3 = createSampleSecuritiesFilter(name: "Filter 3")

        // When
        repository.addFilter(filter1)
        repository.addFilter(filter2)
        repository.addFilter(filter3)

        // Then
        XCTAssertEqual(repository.savedFilters.count, 3)
        XCTAssertTrue(repository.savedFilters.contains { $0.name == "Filter 1" })
        XCTAssertTrue(repository.savedFilters.contains { $0.name == "Filter 2" })
        XCTAssertTrue(repository.savedFilters.contains { $0.name == "Filter 3" })
    }

    func testSavedSecuritiesFiltersRepository_Isolation() {
        // Given - Two separate in-memory UserDefaults
        guard let userDefaults1 = UserDefaults(suiteName: UUID().uuidString),
              let userDefaults2 = UserDefaults(suiteName: UUID().uuidString) else {
            XCTFail("Failed to create in-memory UserDefaults")
            return
        }
        let repository1 = SavedSecuritiesFiltersRepository(userDefaults: userDefaults1)
        let repository2 = SavedSecuritiesFiltersRepository(userDefaults: userDefaults2)

        let filter1 = createSampleSecuritiesFilter(name: "Filter 1")
        let filter2 = createSampleSecuritiesFilter(name: "Filter 2")

        // When
        repository1.addFilter(filter1)
        repository2.addFilter(filter2)

        // Then - Each repository should have its own isolated data
        XCTAssertEqual(repository1.savedFilters.count, 1)
        XCTAssertEqual(repository2.savedFilters.count, 1)
        XCTAssertEqual(repository1.savedFilters.first?.name, "Filter 1")
        XCTAssertEqual(repository2.savedFilters.first?.name, "Filter 2")
    }

    // MARK: - Test Helpers

    private func createSampleSecuritiesFilter(name: String = "Test Filter") -> SecuritiesFilterCombination {
        let searchFilters = SearchFilters(
            category: "Warrant",
            underlyingAsset: "DAX",
            direction: SecuritiesSearchView.Direction.call,
            strikePriceGap: nil,
            remainingTerm: nil,
            issuer: nil,
            omega: nil
        )
        return SecuritiesFilterCombination(
            name: name,
            filters: searchFilters,
            isDefault: false
        )
    }
}
