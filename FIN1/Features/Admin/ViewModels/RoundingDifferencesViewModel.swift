import Foundation
import Combine

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
            .store(in: &cancellables)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            unreconciledDifferences = try await roundingService.getUnreconciledDifferences()
            totalRoundingBalance = try await roundingService.getRoundingDifferenceBalance()
        } catch {
            let appError = error.toAppError()
            errorMessage = appError.errorDescription ?? "An error occurred"
            telemetryService.trackError(error, metadata: ["screen": "admin_rounding_differences_load"])
        }
        isLoading = false
    }

    func reconcileAll() async {
        do {
            let items = unreconciledDifferences
            try await roundingService.reconcileDifferences(items)
            await load()
            telemetryService.trackEvent(name: "rounding_reconcile_all", properties: ["count": items.count])
        } catch {
            let appError = error.toAppError()
            errorMessage = appError.errorDescription ?? "An error occurred"
            telemetryService.trackError(error, metadata: ["screen": "admin_rounding_differences_reconcile_all"])
        }
    }
}
