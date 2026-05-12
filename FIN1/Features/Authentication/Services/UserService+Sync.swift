import Foundation

extension UserService {
    // MARK: - Backend Synchronization

    /// Syncs current user profile to the backend.
    /// Called automatically when app enters background.
    func syncToBackend() async {
        guard let apiClient = parseAPIClient, let user = currentUser else {
            print("⚠️ UserService: No API client or user, skipping sync")
            return
        }

        print("📤 UserService: Syncing user profile to backend...")

        do {
            struct UserUpdateInput: Codable {
                let username: String
                let email: String
                let firstName: String
                let lastName: String
                let phoneNumber: String
                let streetAndNumber: String
                let postalCode: String
                let city: String
                let country: String
            }

            let input = UserUpdateInput(
                username: user.username,
                email: user.email,
                firstName: user.firstName,
                lastName: user.lastName,
                phoneNumber: user.phoneNumber,
                streetAndNumber: user.streetAndNumber,
                postalCode: user.postalCode,
                city: user.city,
                country: user.country
            )

            _ = try await apiClient.updateObject(
                className: "_User",
                objectId: user.id,
                object: input
            )

            print("✅ UserService: Profile synced to backend")
        } catch {
            print("⚠️ Failed to sync user profile: \(error.localizedDescription)")
        }
    }
}
