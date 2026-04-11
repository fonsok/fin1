import Foundation
import Combine

// MARK: - User Service Protocol
/// Defines the contract for user authentication and management operations
protocol UserServiceProtocol: ObservableObject {
    var currentUser: User? { get }
    var isAuthenticated: Bool { get }
    var isLoading: Bool { get }

    /// Parse Server session token for authenticated API calls
    /// Returns nil if not authenticated
    var sessionToken: String? { get }

    // MARK: - Authentication
    func signIn(email: String, password: String) async throws
    func signUp(userData: User) async throws
    func signOut() async

    // MARK: - User Management
    func updateProfile(_ user: User) async throws
    func refreshUserData() async throws

    // MARK: - Backend Synchronization
    func syncToBackend() async

    // MARK: - Role Management (Admin)
    func switchUserRole(to newRole: UserRole) async

    // MARK: - User Impersonation (Admin)
    var isImpersonating: Bool { get }
    var originalAdminUser: User? { get }
    func impersonateUser(userId: String, customerNumber: String, email: String, fullName: String, role: UserRole) async
    func stopImpersonating() async

    // MARK: - User Queries
    var userDisplayName: String { get }
    var userRole: UserRole? { get }
    var isInvestor: Bool { get }
    var isTrader: Bool { get }
}

// MARK: - User Service Implementation
/// Handles user authentication, profile management, and user state
final class UserService: UserServiceProtocol, ServiceLifecycle {
    static let shared = UserService()

    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false

    /// Parse Server session token for authenticated API calls
    /// In production, this would come from Parse.User.login()
    /// For now, we generate a simulated token for test users
    @Published private var _sessionToken: String?
    var sessionToken: String? {
        _sessionToken
    }

    // MARK: - Impersonation State
    @Published private var _originalAdminUser: User?
    var originalAdminUser: User? {
        _originalAdminUser
    }
    var isImpersonating: Bool {
        _originalAdminUser != nil
    }

    private var cancellables = Set<AnyCancellable>()
    private var parseAPIClient: ParseAPIClientProtocol?

    init(parseAPIClient: ParseAPIClientProtocol? = nil) {
        self.parseAPIClient = parseAPIClient
        checkExistingSession()
    }

    /// Configure the API client for backend synchronization
    func configure(parseAPIClient: ParseAPIClientProtocol) {
        self.parseAPIClient = parseAPIClient
    }

    /// Generates a simulated session token for offline/fallback scenarios
    private func generateFallbackSessionToken(for user: User) -> String {
        let payload = "\(user.id):\(user.role.rawValue):\(Date().timeIntervalSince1970)"
        let encoded = Data(payload.utf8).base64EncodedString()
        return "sim:\(encoded)"
    }

    // MARK: - ServiceLifecycle
    func start() { /* e.g., attach listeners, restore session */ }
    func stop() { /* e.g., detach listeners */ }
    func reset() {
        Task {
            await signOut()
        }
    }

    // MARK: - Authentication

    func signIn(email: String, password: String) async throws {
        try UserValidationService.validateSignIn(email: email, password: password)

        await MainActor.run { [weak self] in
            self?.isLoading = true
        }

        // Try real Parse Server login first
        if let apiClient = parseAPIClient {
            do {
                let loginResponse = try await apiClient.login(
                    username: email.lowercased().trimmingCharacters(in: .whitespaces),
                    password: password
                )

                #if DEBUG
                var user = UserFactory.createTestUser(email: email, password: password)
                #else
                var user = UserFactory.createUser(from: email, password: password)
                #endif

                UserFactory.applyLoginResponse(loginResponse, to: &user)

                await MainActor.run { [weak self] in
                    self?.currentUser = user
                    self?._sessionToken = loginResponse.sessionToken
                    self?.isAuthenticated = true
                    self?.isLoading = false
                    NotificationCenter.default.post(name: .userDidSignIn, object: nil)
                }

                do {
                    let me: ParseUserMeResponse = try await apiClient.callFunction(
                        "getUserMe",
                        parameters: nil
                    )
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

        // Fallback: local test user creation (offline or no backend)
        #if DEBUG
        let testUser = UserFactory.createTestUser(email: email, password: password)
        #else
        try UserValidationService.checkForSimulatedErrors(email: email, password: password)
        let testUser = UserFactory.createUser(from: email, password: password)
        #endif

        let token = generateFallbackSessionToken(for: testUser)

        await MainActor.run { [weak self] in
            self?.currentUser = testUser
            self?._sessionToken = token
            self?.isAuthenticated = true
            self?.isLoading = false
            NotificationCenter.default.post(name: .userDidSignIn, object: nil)
        }
    }

    func signUp(userData: User) async throws {
        // Input validation
        try UserValidationService.validateSignUp(userData: userData)

        await MainActor.run { [weak self] in
            self?.isLoading = true
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Check for simulated errors
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
            // Post notification for authentication state change
            NotificationCenter.default.post(name: .userDidSignOut, object: nil)
        }
    }

    // MARK: - User Management

    func updateProfile(_ user: User) async throws {
        // Input validation
        try UserValidationService.validateProfileUpdate(user: user)

        await MainActor.run { [weak self] in
            self?.isLoading = true
        }

        // Update local state first
        await MainActor.run { [weak self] in
            self?.currentUser = user
        }

        // Sync to backend (write-through pattern)
        if let apiClient = parseAPIClient {
            Task.detached { [apiClient, user] in
                do {
                    // Update Parse.User via REST API
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
            // Simulate API call if no backend available
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        // Check for simulated errors
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
                let me: ParseUserMeResponse = try await apiClient.callFunction(
                    "getUserMe",
                    parameters: nil
                )
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

    // MARK: - Role Management (Admin)

    /// Switches the current user's role (for admin testing purposes)
    @MainActor
    func switchUserRole(to newRole: UserRole) async {
        guard let user = currentUser else { return }

        let updatedUser = User(
            id: user.id,
            customerNumber: user.customerNumber,
            accountType: user.accountType,
            email: user.email,
            username: user.username,
            phoneNumber: user.phoneNumber,
            password: user.password,
            salutation: user.salutation,
            academicTitle: user.academicTitle,
            firstName: user.firstName,
            lastName: user.lastName,
            streetAndNumber: user.streetAndNumber,
            postalCode: user.postalCode,
            city: user.city,
            state: user.state,
            country: user.country,
            dateOfBirth: user.dateOfBirth,
            placeOfBirth: user.placeOfBirth,
            countryOfBirth: user.countryOfBirth,
            role: newRole,
            employmentStatus: user.employmentStatus,
            income: user.income,
            incomeRange: user.incomeRange,
            riskTolerance: user.riskTolerance,
            address: user.address,
            nationality: user.nationality,
            additionalNationalities: user.additionalNationalities,
            taxNumber: user.taxNumber,
            additionalTaxResidences: user.additionalTaxResidences,
            isNotUSCitizen: user.isNotUSCitizen,
            identificationType: user.identificationType,
            passportFrontImageURL: user.passportFrontImageURL,
            passportBackImageURL: user.passportBackImageURL,
            idCardFrontImageURL: user.idCardFrontImageURL,
            idCardBackImageURL: user.idCardBackImageURL,
            identificationConfirmed: user.identificationConfirmed,
            addressConfirmed: user.addressConfirmed,
            addressVerificationDocumentURL: user.addressVerificationDocumentURL,
            leveragedProductsExperience: user.leveragedProductsExperience,
            financialProductsExperience: user.financialProductsExperience,
            investmentExperience: user.investmentExperience,
            tradingFrequency: user.tradingFrequency,
            investmentKnowledge: user.investmentKnowledge,
            desiredReturn: user.desiredReturn,
            insiderTradingOptions: user.insiderTradingOptions,
            moneyLaunderingDeclaration: user.moneyLaunderingDeclaration,
            assetType: user.assetType,
            profileImageURL: user.profileImageURL,
            isEmailVerified: user.isEmailVerified,
            isKYCCompleted: user.isKYCCompleted,
            acceptedTerms: user.acceptedTerms,
            acceptedPrivacyPolicy: user.acceptedPrivacyPolicy,
            acceptedMarketingConsent: user.acceptedMarketingConsent,
            acceptedTermsVersion: user.acceptedTermsVersion,
            acceptedTermsDate: user.acceptedTermsDate,
            acceptedPrivacyPolicyVersion: user.acceptedPrivacyPolicyVersion,
            acceptedPrivacyPolicyDate: user.acceptedPrivacyPolicyDate,
            lastLoginDate: user.lastLoginDate,
            createdAt: user.createdAt,
            updatedAt: Date()
        )

        currentUser = updatedUser

        // Notify the app that user data changed
        NotificationCenter.default.post(name: .userDataDidUpdate, object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("UserRoleChanged"), object: newRole)

        print("🔄 UserService: Role switched to \(newRole.displayName)")
    }

    // MARK: - User Impersonation (Admin)

    /// Impersonates a user for testing purposes (admin only)
    /// - Parameters:
    ///   - userId: The user ID to impersonate
    ///   - customerNumber: Business Kundennummer (ANL-/TRD-…)
    ///   - email: The user's email
    ///   - fullName: The user's full name
    ///   - role: The user's role
    @MainActor
    func impersonateUser(userId: String, customerNumber: String, email: String, fullName: String, role: UserRole) async {
        // Store original admin user if not already stored
        if _originalAdminUser == nil, let currentUser = currentUser, currentUser.role == .admin {
            _originalAdminUser = currentUser
            print("💾 UserService: Stored original admin user: \(currentUser.displayName)")
        }

        // Parse full name into first and last name
        let nameComponents = fullName.components(separatedBy: " ")
        let firstName = nameComponents.first ?? ""
        let lastName = nameComponents.dropFirst().joined(separator: " ")

        // Create impersonated user
        let impersonatedUser = User(
            id: userId,
            customerNumber: customerNumber,
            accountType: .individual,
            email: email,
            username: email.components(separatedBy: "@").first ?? "",
            phoneNumber: "",
            password: "",
            salutation: .mr,
            academicTitle: "",
            firstName: firstName,
            lastName: lastName.isEmpty ? firstName : lastName,
            streetAndNumber: "",
            postalCode: "",
            city: "",
            state: "",
            country: "",
            dateOfBirth: Date(),
            placeOfBirth: "",
            countryOfBirth: "",
            role: role,
            employmentStatus: .employed,
            income: 0,
            incomeRange: .low,
            riskTolerance: 3,
            address: "",
            nationality: "",
            additionalNationalities: "",
            taxNumber: "",
            additionalTaxResidences: "",
            isNotUSCitizen: true,
            identificationType: .passport,
            passportFrontImageURL: nil,
            passportBackImageURL: nil,
            idCardFrontImageURL: nil,
            idCardBackImageURL: nil,
            identificationConfirmed: true,
            addressConfirmed: true,
            addressVerificationDocumentURL: nil,
            leveragedProductsExperience: role == .trader,
            financialProductsExperience: role == .investor,
            investmentExperience: role == .investor ? 2 : 0,
            tradingFrequency: role == .trader ? 1 : 0,
            investmentKnowledge: role == .investor ? 2 : 0,
            desiredReturn: role == .trader ? .atLeastHundredPercent : .atLeastTenPercent,
            insiderTradingOptions: [
                "Brokerage or Stock Exchange Employee": false,
                "Director or 10% Shareholder": false,
                "High-Ranking Official": false,
                "None of the above": true
            ],
            moneyLaunderingDeclaration: true,
            assetType: .privateAssets,
            profileImageURL: nil,
            isEmailVerified: true,
            isKYCCompleted: true,
            acceptedTerms: true,
            acceptedPrivacyPolicy: true,
            acceptedMarketingConsent: true,
            acceptedTermsVersion: TermsVersionConstants.currentTermsVersion,
            acceptedTermsDate: Date(),
            acceptedPrivacyPolicyVersion: TermsVersionConstants.currentPrivacyPolicyVersion,
            acceptedPrivacyPolicyDate: Date(),
            lastLoginDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )

        currentUser = impersonatedUser

        // Notify the app that user data changed
        NotificationCenter.default.post(name: .userDataDidUpdate, object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("UserRoleChanged"), object: role)
        NotificationCenter.default.post(name: NSNotification.Name("UserImpersonationStarted"), object: nil)

        print("👤 UserService: Impersonating user \(fullName) (\(role.displayName)) - ID: \(userId)")
    }

    /// Stops impersonation and returns to the original admin user
    @MainActor
    func stopImpersonating() async {
        guard let originalUser = _originalAdminUser else {
            print("⚠️ UserService: No original admin user to return to")
            return
        }

        currentUser = originalUser
        _originalAdminUser = nil

        // Notify the app that user data changed
        NotificationCenter.default.post(name: .userDataDidUpdate, object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("UserRoleChanged"), object: originalUser.role)
        NotificationCenter.default.post(name: NSNotification.Name("UserImpersonationStopped"), object: nil)

        print("🔙 UserService: Stopped impersonation, returned to admin: \(originalUser.displayName)")
    }

    // MARK: - Backend Synchronization

    /// Syncs current user profile to the backend
    /// Called automatically when app enters background
    func syncToBackend() async {
        guard let apiClient = parseAPIClient,
              let user = currentUser else {
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

    // MARK: - Private Methods

    private func checkExistingSession() {
        // TODO: Check for stored authentication tokens
        // For now, always start unauthenticated
        isAuthenticated = false
    }

}
