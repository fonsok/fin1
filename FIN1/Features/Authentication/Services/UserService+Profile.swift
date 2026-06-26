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

        if self.parseAPIClient != nil {
            try await self.syncProfileToBackendIfPossible(user: user)
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

    /// Persists editable profile fields via the authenticated `updateProfile` Cloud Function.
    func syncProfileToBackendIfPossible(user: User) async throws {
        guard let apiClient = parseAPIClient else { return }

        guard DocumentInboxPolicy.isParseObjectId(user.id) else {
            print("⚠️ UserService: Skipping profile sync — user id is not a Parse objectId (\(user.id))")
            return
        }

        guard self.sessionToken?.hasPrefix("r:") == true else {
            print("⚠️ UserService: Skipping profile sync — no Parse session token")
            return
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        let parameters: [String: Any] = [
            "firstName": user.firstName,
            "lastName": user.lastName,
            "salutation": user.salutation.rawValue,
            "phoneNumber": user.phoneNumber,
            "dateOfBirth": dateFormatter.string(from: user.dateOfBirth),
            "streetAndNumber": user.streetAndNumber,
            "postalCode": user.postalCode,
            "city": user.city,
            "country": user.country,
            "state": user.state,
            "username": user.username,
            "email": user.email.lowercased().trimmingCharacters(in: .whitespaces)
        ]

        struct UpdateProfileResponse: Decodable {
            let success: Bool
        }

        let response: UpdateProfileResponse = try await apiClient.callFunction(
            "updateProfile",
            parameters: parameters
        )

        guard response.success else {
            throw AppError.serviceError(.operationFailed)
        }

        print("✅ User profile synced to backend: \(user.id)")
    }
}
