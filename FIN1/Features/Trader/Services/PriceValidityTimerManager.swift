import Combine
import Foundation

// MARK: - Price Validity Timer Manager Protocol
protocol PriceValidityTimerManagerProtocol {
    var priceValidityProgress: Double { get set }
    var isPaused: Bool { get }

    func startTimer()
    func stopTimer()
    /// Stops the staleness ramp but keeps the current progress (e.g. during order placement).
    func pauseTimer()
    /// Continues the staleness ramp from the current progress (does not reset to fresh).
    func resumeTimer()
    func cleanup()
}

// MARK: - Price Validity Timer Manager
/// Drives the Brief-Kurs **staleness indicator** (green → red). This is a UX hint only —
/// not a hard order-validity window. `priceValidityProgress` 1.0 = fresh, 0.0 = likely stale.
final class PriceValidityTimerManager: ObservableObject, PriceValidityTimerManagerProtocol {
    @Published var priceValidityProgress: Double = 1.0
    private(set) var isPaused = false

    private var timerCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    /// Seconds for the indicator to ramp from fresh (green) to likely stale (red).
    private let stalenessRampDuration: TimeInterval = 8.0
    /// UI refresh cadence — 4 Hz is enough for the bar; avoids main-thread churn from 20 Hz.
    private let updateInterval: TimeInterval = 0.25

    func startTimer() {
        self.isPaused = false
        self.stopTimer()
        self.priceValidityProgress = 1.0
        self.attachStalenessTimer()
    }

    func stopTimer() {
        self.isPaused = false
        self.timerCancellable?.cancel()
        self.timerCancellable = nil
    }

    func pauseTimer() {
        self.isPaused = true
        self.timerCancellable?.cancel()
        self.timerCancellable = nil
    }

    func resumeTimer() {
        guard self.timerCancellable == nil else { return }
        guard self.priceValidityProgress > 0 else {
            self.isPaused = false
            return
        }

        self.isPaused = false
        self.attachStalenessTimer()
    }

    func cleanup() {
        self.stopTimer()
        self.cancellables.removeAll()
    }

    private func attachStalenessTimer() {
        self.timerCancellable = Timer.publish(every: self.updateInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, !self.isPaused else { return }

                let decrement = self.updateInterval / self.stalenessRampDuration
                self.priceValidityProgress -= decrement

                if self.priceValidityProgress <= 0 {
                    self.priceValidityProgress = 0
                    self.stopTimer()
                }
            }
    }
}
