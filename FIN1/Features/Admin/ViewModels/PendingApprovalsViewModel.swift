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
            self.pendingCount = 0
            return
        }
        self.isLoading = true
        defer { isLoading = false }

        do {
            let changes = try await configurationService.getPendingConfigurationChanges()
            self.pendingCount = changes.count
        } catch {
            self.pendingCount = 0
        }
    }
}
