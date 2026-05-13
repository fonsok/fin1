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
        self.userDefaults.string(forKey: self.appliedFilterIDKey)
    }

    func setAppliedFilterID(_ id: String) {
        self.userDefaults.set(id, forKey: self.appliedFilterIDKey)
    }

    func clearAppliedFilterID() {
        self.userDefaults.removeObject(forKey: self.appliedFilterIDKey)
    }
}
