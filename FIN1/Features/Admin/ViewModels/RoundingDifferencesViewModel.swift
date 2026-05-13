import Combine
import Foundation

@MainActor
final class RoundingDifferencesViewModel: ObservableObject {
    @Published var unreconciledDifferences: [RoundingDifference] = []
    @Published var totalRoundingBalance: Double = 0.0
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let roundingService: any RoundingDifferencesServiceProtocol
    private let telemetryService: any TelemetryServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(
        roundingService: any RoundingDifferencesServiceProtocol,
        telemetryService: any TelemetryServiceProtocol
    ) {
        self.roundingService = roundingService
        self.telemetryService = telemetryService

        // Live updates
        roundingService.unreconciledDifferencesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] diffs in
                self?.unreconciledDifferences = diffs
            }
            .store(in: &self.cancellables)
    }

    func load() async {
        self.isLoading = true
        self.errorMessage = nil
        do {
            self.unreconciledDifferences = try await self.roundingService.getUnreconciledDifferences()
            self.totalRoundingBalance = try await self.roundingService.getRoundingDifferenceBalance()
        } catch {
            let appError = error.toAppError()
            self.errorMessage = appError.errorDescription ?? "An error occurred"
            self.telemetryService.trackError(error, metadata: ["screen": "admin_rounding_differences_load"])
        }
        self.isLoading = false
    }

    func reconcileAll() async {
        do {
            let items = self.unreconciledDifferences
            try await self.roundingService.reconcileDifferences(items)
            await self.load()
            self.telemetryService.trackEvent(name: "rounding_reconcile_all", properties: ["count": items.count])
        } catch {
            let appError = error.toAppError()
            self.errorMessage = appError.errorDescription ?? "An error occurred"
            self.telemetryService.trackError(error, metadata: ["screen": "admin_rounding_differences_reconcile_all"])
        }
    }
}
