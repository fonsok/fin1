import Combine
import Foundation

// MARK: - Price Validity Timer Manager Protocol
protocol PriceValidityTimerManagerProtocol {
    var priceValidityProgress: Double { get set }

    func startTimer()
    func stopTimer()
    func cleanup()
}

// MARK: - Price Validity Timer Manager
/// Manages price validity timer lifecycle and progress tracking
final class PriceValidityTimerManager: ObservableObject, PriceValidityTimerManagerProtocol {
    @Published var priceValidityProgress: Double = 1.0

    private var timerCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private let duration: TimeInterval = 5.0
    private let updateInterval: TimeInterval = 0.05

    func startTimer() {
        // Cancel any existing timer first
        self.stopTimer()
        self.priceValidityProgress = 1.0

        self.timerCancellable = Timer.publish(every: self.updateInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }

                let decrement = self.updateInterval / self.duration
                self.priceValidityProgress -= decrement

                if self.priceValidityProgress <= 0 {
                    self.priceValidityProgress = 0
                    self.stopTimer()
                }
            }

        // Store the timer cancellable to manage its lifecycle
        self.timerCancellable?.store(in: &self.cancellables)
    }

    func stopTimer() {
        self.timerCancellable?.cancel()
        self.timerCancellable = nil
    }

    func cleanup() {
        self.stopTimer()
        self.cancellables.removeAll()
    }
}
