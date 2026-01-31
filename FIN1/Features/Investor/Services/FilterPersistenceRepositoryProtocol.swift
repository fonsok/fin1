import Foundation

// MARK: - Filter Persistence Repository Protocol
protocol FilterPersistenceRepositoryProtocol {
    func getAppliedFilterID() -> String?
    func setAppliedFilterID(_ id: String)
    func clearAppliedFilterID()
}

// MARK: - UserDefaults-backed Implementation
final class FilterPersistenceRepository: FilterPersistenceRepositoryProtocol {
    private let appliedFilterIDKey = "currentlyAppliedFilterID"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func getAppliedFilterID() -> String? {
        userDefaults.string(forKey: appliedFilterIDKey)
    }

    func setAppliedFilterID(_ id: String) {
        userDefaults.set(id, forKey: appliedFilterIDKey)
    }

    func clearAppliedFilterID() {
        userDefaults.removeObject(forKey: appliedFilterIDKey)
    }
}
