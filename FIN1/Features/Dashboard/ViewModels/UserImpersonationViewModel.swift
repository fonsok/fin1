import Combine
import Foundation
import SwiftUI

// MARK: - User Impersonation ViewModel
/// ViewModel for user impersonation search following MVVM architecture
@MainActor
final class UserImpersonationViewModel: ObservableObject {
    // MARK: - Dependencies
    private var customerSupportService: any CustomerSupportServiceProtocol
    private var userService: any UserServiceProtocol

    // MARK: - Published Properties
    @Published var searchQuery = ""
    @Published var searchResults: [CustomerSearchResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - Private Properties
    private nonisolated(unsafe) var cancellables = Set<AnyCancellable>()
    private var debounceTask: Task<Void, Never>?

    // MARK: - Initialization
    init(
        customerSupportService: any CustomerSupportServiceProtocol,
        userService: any UserServiceProtocol
    ) {
        self.customerSupportService = customerSupportService
        self.userService = userService
        self.setupSearchObserver()
    }

    deinit {
        debounceTask?.cancel()
        cancellables.removeAll()
    }

    // MARK: - Setup
    private func setupSearchObserver() {
        self.$searchQuery
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &self.cancellables)
    }

    // MARK: - Public Methods
    func performSearch(query: String? = nil) {
        let searchText = query ?? self.searchQuery
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Cancel previous search task
        self.debounceTask?.cancel()

        guard !trimmedQuery.isEmpty else {
            self.searchResults = []
            self.isLoading = false
            self.errorMessage = nil
            return
        }

        self.isLoading = true
        self.errorMessage = nil
        self.showError = false

        self.debounceTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                let results = try await self.customerSupportService.searchCustomers(query: trimmedQuery)
                await MainActor.run {
                    self.searchResults = results
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    let appError = self.mapToAppError(error)
                    self.errorMessage = appError.errorDescription ?? "Search failed"
                    self.isLoading = false
                    self.showError = true
                }
            }
        }
    }

    func clearSearch() {
        self.debounceTask?.cancel()
        self.searchQuery = ""
        self.searchResults = []
        self.errorMessage = nil
        self.showError = false
    }

    func impersonateUser(_ result: CustomerSearchResult) async {
        let userRole = self.mapRoleStringToEnum(result.role)

        await self.userService.impersonateUser(
            userId: result.id,
            customerNumber: result.customerNumber,
            email: result.email,
            fullName: result.fullName,
            role: userRole
        )
    }

    // MARK: - Reconfiguration
    /// Reconfigures ViewModel with services from environment (single container to avoid omissions)
    func reconfigure(with services: AppServices) {
        // Cancel existing subscriptions
        self.cancellables.removeAll()
        self.debounceTask?.cancel()

        self.customerSupportService = services.customerSupportService
        self.userService = services.userService

        // Re-setup search observer with new services
        self.setupSearchObserver()
    }

    // MARK: - Private Methods
    private func mapRoleStringToEnum(_ roleString: String) -> UserRole {
        switch roleString.lowercased() {
        case "investor":
            return .investor
        case "trader":
            return .trader
        case "admin":
            return .admin
        case "customerservice", "csr", "kundenberater":
            return .customerService
        default:
            return .other
        }
    }

    /// Maps various error types to AppError for consistent error handling
    /// Note: This method is kept for backward compatibility but delegates to the shared extension
    private func mapToAppError(_ error: Error) -> AppError {
        return error.toAppError()
    }
}
