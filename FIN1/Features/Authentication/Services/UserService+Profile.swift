import Foundation

extension UserService {
    // MARK: - User Management

    func updateProfile(_ user: User) async throws {
        try UserValidationService.validateProfileUpdate(user: user)

        await MainActor.run { [weak self] in
            self?.isLoading = true
        }

        await MainActor.run { [weak self] in
            self?.currentUser = user
        }

        if let apiClient = parseAPIClient {
            Task {
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
                    print("✅ User profile synced to backend: \(user.id)")
                } catch {
                    print("⚠️ Failed to sync user profile to backend: \(error.localizedDescription)")
                }
            }
        } else {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        try UserValidationService.checkForProfileUpdateErrors(user: user)

        await MainActor.run { [weak self] in
            self?.isLoading = false
        }
    }

    func refreshUserData() async throws {
        guard let user = currentUser else {
            throw AppError.serviceError(.dataNotFound)
        }

        if let apiClient = parseAPIClient {
            do {
                let me: ParseUserMeResponse = try await apiClient.callFunction("getUserMe", parameters: nil)
                await MainActor.run { [weak self] in
                    guard let self, var updated = self.currentUser else { return }
                    UserFactory.applyUserMeResponse(me, to: &updated)
                    self.currentUser = updated
                    NotificationCenter.default.post(name: .userDataDidUpdate, object: nil)
                }
                return
            } catch {
                print("⚠️ UserService: refreshUserData from backend failed (\(error.localizedDescription)), using local data")
            }
        }

        try await Task.sleep(nanoseconds: 500_000_000)
        try UserValidationService.checkForRefreshErrors(currentUser: user)
    }
}
