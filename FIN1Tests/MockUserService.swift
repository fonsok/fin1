import Foundation
import Combine
@testable import FIN1

// MARK: - Mock User Service
final class MockUserService: UserServiceProtocol, @unchecked Sendable {
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false

    var sessionToken: String? {
        guard let user = currentUser else { return nil }
        // Generate test session token
        let payload = "\(user.id):\(user.role.rawValue):\(Date().timeIntervalSince1970)"
        let encoded = Data(payload.utf8).base64EncodedString()
        return "r:\(encoded)"
    }

    var userDisplayName: String { currentUser?.displayName ?? "Guest" }
    var userRole: UserRole? { currentUser?.role }
    var isInvestor: Bool { currentUser?.role == .investor }
    var isTrader: Bool { currentUser?.role == .trader }

    // MARK: - Impersonation State
    private var _originalAdminUser: User?
    var originalAdminUser: User? { _originalAdminUser }
    var isImpersonating: Bool { _originalAdminUser != nil }

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
            isLoading = true

            // Create test user based on email
            let user = User(
                id: UUID().uuidString,
                customerNumber: "CUST001",
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
                csrRole: nil,
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

            currentUser = user
            isAuthenticated = true
            isLoading = false
        }
    }

    func signUp(userData: User) async throws {
        if let handler = signUpHandler {
            try await handler(userData)
        } else {
            // Default: set user
            isLoading = true
            currentUser = userData
            isAuthenticated = true
            isLoading = false
        }
    }

    func signOut() async {
        currentUser = nil
        isAuthenticated = false
        _originalAdminUser = nil
    }

    func updateProfile(_ user: User) async throws {
        if let handler = updateProfileHandler {
            try await handler(user)
        } else {
            // Default: update user
            currentUser = user
        }
    }

    func refreshUserData() async throws {
        if let handler = refreshUserDataHandler {
            try await handler()
        }
        // Default: no-op
    }

    func syncToBackend() async {
        // Mock: no-op
    }

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
            csrRole: user.csrRole,
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
            lastLoginDate: user.lastLoginDate,
            createdAt: user.createdAt,
            updatedAt: Date()
        )
        currentUser = updatedUser
    }

    func impersonateUser(userId: String, customerNumber: String, email: String, fullName: String, role: UserRole) async {
        // Store original admin user if not already stored
        if _originalAdminUser == nil, let currentUser = currentUser, currentUser.role == .admin {
            _originalAdminUser = currentUser
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
            csrRole: nil,
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
            lastLoginDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )

        currentUser = impersonatedUser
    }

    func stopImpersonating() async {
        guard let originalUser = _originalAdminUser else { return }
        currentUser = originalUser
        _originalAdminUser = nil
    }

    func start() {}
    func stop() {}
    func reset() {
        currentUser = nil
        isAuthenticated = false
        isLoading = false
        _originalAdminUser = nil
        // Reset all handlers
        signInHandler = nil
        signUpHandler = nil
        updateProfileHandler = nil
        refreshUserDataHandler = nil
    }
}
