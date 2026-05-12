import Foundation

@MainActor
final class PendingApprovalsViewModel: ObservableObject {
    private var configurationService: (any ConfigurationServiceProtocol)?

    @Published var pendingCount = 0
    @Published var isLoading = false

    func configure(with configurationService: any ConfigurationServiceProtocol) {
        self.configurationService = configurationService
    }

    func loadPendingCount() async {
        guard let configurationService else {
            pendingCount = 0
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let changes = try await configurationService.getPendingConfigurationChanges()
            pendingCount = changes.count
        } catch {
            pendingCount = 0
        }
    }
}
