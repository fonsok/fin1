import Foundation

extension UserService {
    // MARK: - Backend Synchronization

    /// Syncs current user profile to the backend.
    /// Called automatically when app enters background.
    func syncToBackend() async {
        guard let user = currentUser else {
            print("⚠️ UserService: No API client or user, skipping sync")
            return
        }

        print("📤 UserService: Syncing user profile to backend...")

        do {
            try await self.syncProfileToBackendIfPossible(user: user)
            print("✅ UserService: Profile synced to backend")
        } catch {
            print("⚠️ Failed to sync user profile: \(error.localizedDescription)")
        }
    }
}
