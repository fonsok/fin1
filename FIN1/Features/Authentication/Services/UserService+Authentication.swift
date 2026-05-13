import Foundation

extension UserService {
    /// Generates a simulated session token for offline/fallback scenarios.
    func generateFallbackSessionToken(for user: User) -> String {
        let payload = "\(user.id):\(user.role.rawValue):\(Date().timeIntervalSince1970)"
        let encoded = Data(payload.utf8).base64EncodedString()
        return "sim:\(encoded)"
    }

    // MARK: - Authentication

    func signIn(email: String, password: String) async throws {
        try UserValidationService.validateSignIn(email: email, password: password)

        await MainActor.run { [weak self] in
            self?.isLoading = true
        }

        if let apiClient = parseAPIClient {
            do {
                let loginResponse = try await apiClient.login(
                    username: email.lowercased().trimmingCharacters(in: .whitespaces),
                    password: password
                )

                #if DEBUG
                var builtUser = UserFactory.createTestUser(email: email, password: password)
                #else
                var builtUser = UserFactory.createUser(from: email, password: password)
                #endif

                UserFactory.applyLoginResponse(loginResponse, to: &builtUser)
                let user = builtUser

                await MainActor.run { [weak self] in
                    self?.currentUser = user
                    self?._sessionToken = loginResponse.sessionToken
                    self?.isAuthenticated = true
                    self?.isLoading = false
                    NotificationCenter.default.post(name: .userDidSignIn, object: nil)
                }

                do {
                    let me: ParseUserMeResponse = try await apiClient.callFunction("getUserMe", parameters: nil)
                    await MainActor.run { [weak self] in
                        guard var u = self?.currentUser else { return }
                        UserFactory.applyUserMeResponse(me, to: &u)
                        self?.currentUser = u
                        NotificationCenter.default.post(name: .userDataDidUpdate, object: nil)
                    }
                } catch {
                    print("⚠️ UserService: getUserMe after login failed (\(error.localizedDescription))")
                }
                return
            } catch {
                print("⚠️ UserService: Parse login failed (\(error.localizedDescription)), falling back to local auth")
            }
        }

        #if DEBUG
        let testUser = UserFactory.createTestUser(email: email, password: password)
        #else
        try UserValidationService.checkForSimulatedErrors(email: email, password: password)
        let testUser = UserFactory.createUser(from: email, password: password)
        #endif

        let token = self.generateFallbackSessionToken(for: testUser)

        await MainActor.run { [weak self] in
            self?.currentUser = testUser
            self?._sessionToken = token
            self?.isAuthenticated = true
            self?.isLoading = false
            NotificationCenter.default.post(name: .userDidSignIn, object: nil)
        }
    }

    func signUp(userData: User) async throws {
        try UserValidationService.validateSignUp(userData: userData)

        await MainActor.run { [weak self] in
            self?.isLoading = true
        }

        try await Task.sleep(nanoseconds: 2_000_000_000)
        try UserValidationService.checkForSignUpErrors(userData: userData)

        await MainActor.run { [weak self] in
            self?.currentUser = userData
            self?.isAuthenticated = true
            self?.isLoading = false
        }
    }

    func signOut() async {
        await MainActor.run { [weak self] in
            self?.currentUser = nil
            self?._sessionToken = nil
            self?.isAuthenticated = false
            NotificationCenter.default.post(name: .userDidSignOut, object: nil)
        }
    }
}
