import Foundation
import Combine
@testable import FIN1

// MARK: - Mock User Service
class MockUserService: UserServiceProtocol {
    @Published var currentUser: User?
    var currentUserPublished: Published<User?> { _currentUser }
    var currentUserPublisher: Published<User?>.Publisher { $currentUser }

    @Published var isAuthenticated: Bool = false
    var isAuthenticatedPublished: Published<Bool> { _isAuthenticated }
    var isAuthenticatedPublisher: Published<Bool>.Publisher { $isAuthenticated }

    @Published var isLoading: Bool = false
    var isLoadingPublished: Published<Bool> { _isLoading }
    var isLoadingPublisher: AnyPublisher<Bool, Never> { $isLoading.eraseToAnyPublisher() }

    var userDisplayName: String { currentUser?.displayName ?? "Guest" }
    var userRole: UserRole? { currentUser?.role }
    var isInvestor: Bool { currentUser?.role == .investor }
    var isTrader: Bool { currentUser?.role == .trader }

    // MARK: - Behavior Closures (Simplified Approach)
    /// Closure to handle signIn - defaults to creating test user
    var signInHandler: ((String, String) async throws -> Void)?

    /// Closure to handle signUp - defaults to setting user
    var signUpHandler: ((User) async throws -> Void)?

    /// Closure to handle updateProfile - defaults to updating user
    var updateProfileHandler: ((User) async throws -> Void)?

    /// Closure to handle refreshUserData - defaults to no-op
    var refreshUserDataHandler: (() async throws -> Void)?

    func signIn(email: String, password: String) async throws {
        if let handler = signInHandler {
            try await handler(email, password)
        } else {
            // Default: create test user based on email
            await MainActor.run {
                self.isLoading = true
            }

            // Create test user based on email
            let user = User(
            id: UUID().uuidString,
            customerId: "CUST001",
            accountType: .individual,
            email: email,
            username: email.components(separatedBy: "@").first ?? "testuser",
            phoneNumber: "+1234567890",
            password: password,
            salutation: .mr,
            academicTitle: "",
            firstName: "Test",
            lastName: "User",
            streetAndNumber: "123 Test St",
            postalCode: "12345",
            city: "Test City",
            state: "TS",
            country: "Test Country",
            dateOfBirth: Date(),
            placeOfBirth: "Test City",
            countryOfBirth: "Test Country",
            role: email.contains("trader") ? .trader : .investor,
            employmentStatus: .employed,
            income: 50000,
            incomeRange: .middle,
            riskTolerance: 3,
            address: "123 Test St",
            nationality: "Test",
            additionalNationalities: "",
            taxNumber: "123456789",
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
            leveragedProductsExperience: email.contains("trader"),
            financialProductsExperience: true,
            investmentExperience: 2,
            tradingFrequency: email.contains("trader") ? 1 : 0,
            investmentKnowledge: 2,
            desiredReturn: email.contains("trader") ? .atLeastHundredPercent : .atLeastTenPercent,
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
            lastLoginDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )

        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
            self.isLoading = false
        }
        }
    }

    func signUp(userData: User) async throws {
        if let handler = signUpHandler {
            try await handler(userData)
        } else {
            // Default: set user
            await MainActor.run {
                self.isLoading = true
            }

            await MainActor.run {
                self.currentUser = userData
                self.isAuthenticated = true
                self.isLoading = false
            }
        }
    }

    func signOut() async {
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }

    func updateProfile(_ user: User) async throws {
        if let handler = updateProfileHandler {
            try await handler(user)
        } else {
            // Default: update user
            await MainActor.run {
                self.currentUser = user
            }
        }
    }

    func refreshUserData() async throws {
        if let handler = refreshUserDataHandler {
            try await handler()
        }
        // Default: no-op
    }

    func start() {}
    func stop() {}
    func reset() {
        currentUser = nil
        isAuthenticated = false
        isLoading = false
        // Reset all handlers
        signInHandler = nil
        signUpHandler = nil
        updateProfileHandler = nil
        refreshUserDataHandler = nil
    }
}
