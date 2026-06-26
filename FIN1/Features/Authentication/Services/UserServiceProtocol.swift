import Combine
import Foundation

// MARK: - User Service Protocol
/// Defines the contract for user authentication and management operations
protocol UserServiceProtocol: ObservableObject, Sendable {
    var currentUser: User? { get }
    var isAuthenticated: Bool { get }
    var isLoading: Bool { get }

    /// Parse Server session token for authenticated API calls
    /// Returns nil if not authenticated
    var sessionToken: String? { get }

    // MARK: - Authentication
    func signIn(email: String, password: String) async throws
    func signUp(userData: User, isEarlyAccount: Bool) async throws
    func signOut() async

    // MARK: - User Management
    func updateProfile(_ user: User) async throws
    func refreshUserData() async throws
    func applyRiskTolerance(_ riskTolerance: Int) async

    /// Marks onboarding complete on the local session user (after server verification step).
    func applyOnboardingCompletion(onboardingStep: String) async

    /// Ensures Gate 2 role agreement flags remain on the session user when getUserMe lags.
    func applyRoleAgreementAcceptanceIfNeeded(role: UserRole, version: String?, accepted: Bool) async

    // MARK: - Backend Synchronization
    func syncToBackend() async

    // MARK: - Role Management (Admin)
    func switchUserRole(to newRole: UserRole) async

    // MARK: - User Queries
    var userDisplayName: String { get }
    var userRole: UserRole? { get }
    var isInvestor: Bool { get }
    var isTrader: Bool { get }
}

extension UserServiceProtocol {
    func signUp(userData: User) async throws {
        try await self.signUp(userData: userData, isEarlyAccount: false)
    }
}

// MARK: - User Service Implementation
/// Handles user authentication, profile management, and user state
final class UserService: UserServiceProtocol, ServiceLifecycle, @unchecked Sendable {
    static let shared = UserService()

    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false

    /// Parse Server session token for authenticated API calls
    /// In production, this would come from Parse.User.login()
    /// For now, we generate a simulated token for test users
    @Published var _sessionToken: String?
    var sessionToken: String? {
        self._sessionToken
    }

    var cancellables = Set<AnyCancellable>()
    var parseAPIClient: ParseAPIClientProtocol?

    init(parseAPIClient: ParseAPIClientProtocol? = nil) {
        self.parseAPIClient = parseAPIClient
        self.checkExistingSession()
    }

    /// Configure the API client for backend synchronization
    func configure(parseAPIClient: ParseAPIClientProtocol) {
        self.parseAPIClient = parseAPIClient
    }

    // MARK: - ServiceLifecycle
    func start() { /* e.g., attach listeners, restore session */ }
    func stop() { /* e.g., detach listeners */ }
    func reset() {
        Task {
            await signOut()
        }
    }

    func checkExistingSession() {
        // TODO: Check for stored authentication tokens
        // For now, always start unauthenticated
        self.isAuthenticated = false
    }
}
