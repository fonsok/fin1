import Foundation
import Combine

// MARK: - User Service Protocol
/// Defines the contract for user authentication and management operations
protocol UserServiceProtocol: ObservableObject {
    var currentUser: User? { get }
    var isAuthenticated: Bool { get }
    var isLoading: Bool { get }

    // MARK: - Authentication
    func signIn(email: String, password: String) async throws
    func signUp(userData: User) async throws
    func signOut() async

    // MARK: - User Management
    func updateProfile(_ user: User) async throws
    func refreshUserData() async throws

    // MARK: - Role Management (Admin)
    func switchUserRole(to newRole: UserRole) async

    // MARK: - User Impersonation (Admin)
    var isImpersonating: Bool { get }
    var originalAdminUser: User? { get }
    func impersonateUser(userId: String, customerId: String, email: String, fullName: String, role: UserRole) async
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

    // MARK: - Impersonation State
    @Published private var _originalAdminUser: User?
    var originalAdminUser: User? {
        _originalAdminUser
    }
    var isImpersonating: Bool {
        _originalAdminUser != nil
    }

    private var cancellables = Set<AnyCancellable>()

    init() {
        checkExistingSession()
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
        // Input validation
        try UserValidationService.validateSignIn(email: email, password: password)

        await MainActor.run {
            isLoading = true
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        #if DEBUG
        // Check if this is a test user login
        if email.contains("test@") || email.contains("trader") || email.contains("investor") || email.contains("biometric@") || email.contains("admin") || email.contains("csr") || email.contains("customerService") || email.contains("kundenberater") {
            await MainActor.run {
                let testUser = UserFactory.createTestUser(email: email, password: password)
                print("🔍 UserService.signIn (test user):")
                print("   📧 Email: \(email)")
                print("   👤 User ID: '\(testUser.id)'")
                print("   👤 User role: \(testUser.role.rawValue)")
                print("   👤 User name: \(testUser.displayName)")
                self.currentUser = testUser
                self.isAuthenticated = true
                self.isLoading = false
                // Post notification for authentication state change
                NotificationCenter.default.post(name: .userDidSignIn, object: nil)
            }
            return
        }
        #endif

        // Check for simulated errors
        try UserValidationService.checkForSimulatedErrors(email: email, password: password)

        // Create regular user
        let user = UserFactory.createUser(from: email, password: password)

        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
            self.isLoading = false
            // Post notification for authentication state change
            NotificationCenter.default.post(name: .userDidSignIn, object: nil)
        }
    }

    func signUp(userData: User) async throws {
        // Input validation
        try UserValidationService.validateSignUp(userData: userData)

        await MainActor.run {
            isLoading = true
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Check for simulated errors
        try UserValidationService.checkForSignUpErrors(userData: userData)

        await MainActor.run {
            self.currentUser = userData
            self.isAuthenticated = true
            self.isLoading = false
        }
    }

    func signOut() async {
        await MainActor.run {
            currentUser = nil
            isAuthenticated = false
            // Post notification for authentication state change
            NotificationCenter.default.post(name: .userDidSignOut, object: nil)
        }

        // TODO: Clear stored tokens and data
    }

    // MARK: - User Management

    func updateProfile(_ user: User) async throws {
        // Input validation
        try UserValidationService.validateProfileUpdate(user: user)

        await MainActor.run {
            isLoading = true
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Check for simulated errors
        try UserValidationService.checkForProfileUpdateErrors(user: user)

        await MainActor.run {
            self.currentUser = user
            self.isLoading = false
        }
    }

    func refreshUserData() async throws {
        guard let currentUser = currentUser else {
            throw AppError.serviceError(.dataNotFound)
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Check for simulated errors
        try UserValidationService.checkForRefreshErrors(currentUser: currentUser)
    }

    // MARK: - Role Management (Admin)

    /// Switches the current user's role (for admin testing purposes)
    @MainActor
    func switchUserRole(to newRole: UserRole) async {
        guard let user = currentUser else { return }

        let updatedUser = User(
            id: user.id,
            customerId: user.customerId,
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
    ///   - customerId: The customer ID
    ///   - email: The user's email
    ///   - fullName: The user's full name
    ///   - role: The user's role
    @MainActor
    func impersonateUser(userId: String, customerId: String, email: String, fullName: String, role: UserRole) async {
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
            customerId: customerId,
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

    // MARK: - Private Methods

    private func checkExistingSession() {
        // TODO: Check for stored authentication tokens
        // For now, always start unauthenticated
        isAuthenticated = false
    }

}
