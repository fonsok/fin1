import Foundation
import SwiftUI

// MARK: - Landing ViewModel
/// Handles business logic for the landing page, including debug login functionality
@MainActor
final class LandingViewModel: ObservableObject {
    // MARK: - Design Style

    enum DesignStyle: String, CaseIterable {
        case original = "Original"
        case typewriter = "Typewriter"
    }

    // MARK: - Published Properties

    @Published var showDebugButtons = true
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var designStyle: DesignStyle = .original

    // MARK: - Dependencies

    private let userService: any UserServiceProtocol

    // MARK: - Initialization

    init(userService: any UserServiceProtocol) {
        self.userService = userService
    }

    // MARK: - Debug Login Methods

    /// Signs in as an investor test user
    /// - Parameters:
    ///   - number: Investor number (1-5)
    func signInAsInvestor(number: Int) async {
        #if DEBUG
        let email = "investor\(number)@test.com"
        await performDebugLogin(email: email, role: "Investor \(number)")
        #endif
    }

    /// Signs in as a trader test user
    /// - Parameters:
    ///   - number: Trader number (1-3)
    func signInAsTrader(number: Int) async {
        #if DEBUG
        let email = "trader\(number)@test.com"
        await performDebugLogin(email: email, role: "Trader \(number)")
        #endif
    }

    /// Signs in as an admin test user
    func signInAsAdmin() async {
        #if DEBUG
        let email = "admin@test.com"
        await performDebugLogin(email: email, role: "Admin")
        #endif
    }

    /// Signs in as a CSR (Customer Service Representative) test user
    /// - Parameters:
    ///   - number: CSR number (1-3) - Legacy support
    func signInAsCSR(number: Int) async {
        #if DEBUG
        let email = "csr\(number)@test.com"
        await performDebugLogin(email: email, role: "CSR \(number)")
        #endif
    }

    /// Signs in as a CSR with a specific role
    /// - Parameters:
    ///   - role: The CSR role (L1, L2, Fraud, Compliance, Tech Support, Teamlead)
    func signInAsCSRWithRole(_ role: CSRRole) async {
        #if DEBUG
        let email = "csr-\(role.rawValue.lowercased().replacingOccurrences(of: " ", with: "-"))@test.com"
        await self.performDebugLogin(email: email, role: role.displayName)
        #endif
    }

    // MARK: - Private Methods

    /// Performs the actual debug login operation
    /// - Parameters:
    ///   - email: Email address for the test user
    ///   - role: Role name for logging purposes
    private func performDebugLogin(email: String, role: String) async {
        self.isLoading = true
        self.errorMessage = nil
        self.showError = false

        print("🔐 Attempting to sign in as \(role) with email: \(email)")

        do {
            // Must satisfy Parse Server password policy (uppercase/lowercase/digit/special)
            try await self.userService.signIn(email: email, password: TestConstants.password)
            print("✅ \(role) sign-in successful")
            self.isLoading = false
        } catch {
            let appError = error.toAppError()
            let errorMsg = "\(role) sign-in failed: \(appError.errorDescription ?? "An error occurred")"
            print("❌ \(errorMsg)")
            self.errorMessage = errorMsg
            self.showError = true
            self.isLoading = false
        }
    }
}



