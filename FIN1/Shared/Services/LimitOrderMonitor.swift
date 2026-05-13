import Combine
import Foundation

// MARK: - Limit Order Monitor Protocol
/// Protocol defining the contract for limit order monitoring functionality
@MainActor
protocol LimitOrderMonitor: ObservableObject {
    var isMonitoringLimitOrder: Bool { get set }
    var shouldShowDepotView: Bool { get set }

    // Price comparison logic (to be implemented by conforming types)
    var currentPriceValue: Double { get }
    var limitPrice: Double? { get }

    // Order execution (to be implemented by conforming types)
    func placeOrder() async
    func startPriceValidityTimer()
    func reloadPrice()

    // Monitoring control
    func startLimitOrderMonitoring()
    func stopLimitOrderMonitoring()
}

// MARK: - Limit Order Monitor Implementation
/// Shared implementation of limit order monitoring logic
@MainActor
class LimitOrderMonitorImpl {
    @Published var isMonitoringLimitOrder: Bool = false

    private var limitOrderTimer: Timer?
    private var limitOrderExecutionTimer: Timer?
    private var limitOrderRefreshCount: Int = 0

    private weak var monitor: (any LimitOrderMonitor)?

    init(monitor: any LimitOrderMonitor) {
        self.monitor = monitor
    }

    // MARK: - Monitoring Control

    func startLimitOrderMonitoring() {
        guard let monitor = monitor else { return }
        guard monitor.limitPrice != nil else { return }

        self.isMonitoringLimitOrder = true
        monitor.isMonitoringLimitOrder = true
        self.limitOrderRefreshCount = 0 // Reset refresh counter
        print("🔍 DEBUG: Starting automatic limit order monitoring")

        // Start monitoring every 2 seconds (timer fires off main runloop; hop to MainActor for @MainActor state)
        self.limitOrderTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkLimitOrderCondition()
            }
        }

        // Check immediately
        self.checkLimitOrderCondition()
    }

    func stopLimitOrderMonitoring() {
        self.isMonitoringLimitOrder = false
        self.monitor?.isMonitoringLimitOrder = false
        self.limitOrderTimer?.invalidate()
        self.limitOrderTimer = nil
        self.limitOrderExecutionTimer?.invalidate()
        self.limitOrderExecutionTimer = nil
        print("🔍 DEBUG: Stopped automatic limit order monitoring")
    }

    // MARK: - Private Methods

    private func checkLimitOrderCondition() {
        guard let monitor = monitor else { return }
        guard let limitPrice = monitor.limitPrice else { return }

        print(
            "🔍 DEBUG: Checking limit order condition - currentPrice: \(monitor.currentPriceValue), limitPrice: \(limitPrice), refreshCount: \(self.limitOrderRefreshCount)"
        )

        // Check if limit condition is met (to be implemented by specific order types)
        let conditionMet = self.shouldExecuteLimitOrder(currentPrice: monitor.currentPriceValue, limitPrice: limitPrice)

        if conditionMet || self.limitOrderRefreshCount >= 5 {
            // Only start execution timer if one isn't already running
            if self.limitOrderExecutionTimer == nil {
                if self.limitOrderRefreshCount >= 5 {
                    print("🔍 DEBUG: Maximum 5 refreshes reached! Forcing limit condition to be met")
                } else {
                    print("🔍 DEBUG: Limit condition met naturally! Starting 2-second countdown to execute order")
                }

                // Wait 2 seconds then execute (avoid capturing `monitor` in a @Sendable timer closure)
                self.limitOrderExecutionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self, let monitor = self.monitor else { return }
                        await monitor.placeOrder()
                        self.stopLimitOrderMonitoring()
                    }
                }
            } else {
                print("🔍 DEBUG: Execution timer already running, skipping")
            }
        } else {
            // Increment refresh counter and refresh price
            self.limitOrderRefreshCount += 1
            print("🔍 DEBUG: Refreshing price (attempt \(self.limitOrderRefreshCount)/5)")

            // Randomly decide if this refresh should meet the limit condition
            // Higher probability on later refreshes, but can happen on any refresh
            let shouldMeetLimit = self.shouldRandomlyMeetLimitCondition(refreshCount: self.limitOrderRefreshCount)

            if shouldMeetLimit {
                print("🔍 DEBUG: Randomly meeting limit condition on refresh \(self.limitOrderRefreshCount)")
                self.adjustPriceToMeetLimit(limitPrice: limitPrice)
            } else if self.limitOrderRefreshCount == 5 {
                // Fallback: ensure it happens on the 5th refresh if it hasn't happened yet
                print("🔍 DEBUG: 5th refresh - forcing limit condition to be met")
                self.adjustPriceToMeetLimit(limitPrice: limitPrice)
            } else {
                // Trigger normal price reload
                monitor.reloadPrice()
            }
        }
    }

    // MARK: - Random Limit Condition Logic

    /// Determines if the limit condition should be randomly met on this refresh
    /// - Parameter refreshCount: Current refresh count (1-5)
    /// - Returns: True if limit condition should be met, false otherwise
    private func shouldRandomlyMeetLimitCondition(refreshCount: Int) -> Bool {
        // Probability increases with each refresh to make it more realistic
        // Refresh 1: 10% chance
        // Refresh 2: 25% chance
        // Refresh 3: 40% chance
        // Refresh 4: 60% chance
        // Refresh 5: 100% chance (fallback)

        let probabilities: [Double] = [0.1, 0.25, 0.4, 0.6, 1.0]
        let probability = probabilities[min(refreshCount - 1, 4)]

        let randomValue = Double.random(in: 0...1)
        return randomValue <= probability
    }

    // MARK: - Abstract Methods (to be implemented by specific order types)

    /// Determines if the limit order condition is met based on order type
    /// - Parameters:
    ///   - currentPrice: Current market price
    ///   - limitPrice: User-set limit price
    /// - Returns: True if condition is met, false otherwise
    func shouldExecuteLimitOrder(currentPrice: Double, limitPrice: Double) -> Bool {
        // This will be overridden by specific implementations
        return false
    }

    /// Adjusts the price to meet the limit condition on the 5th refresh
    /// - Parameter limitPrice: The limit price to meet
    func adjustPriceToMeetLimit(limitPrice: Double) {
        // This will be overridden by specific implementations
    }
}

// MARK: - Buy Order Monitor Implementation
class BuyOrderMonitorImpl: LimitOrderMonitorImpl {
    private weak var buyOrderViewModel: BuyOrderViewModel?

    init(buyOrderViewModel: BuyOrderViewModel) {
        self.buyOrderViewModel = buyOrderViewModel
        super.init(monitor: buyOrderViewModel)
    }

    override func shouldExecuteLimitOrder(currentPrice: Double, limitPrice: Double) -> Bool {
        // For buy orders: execute when current price is below or equal to limit
        return currentPrice <= limitPrice
    }

    override func adjustPriceToMeetLimit(limitPrice: Double) {
        guard let viewModel = buyOrderViewModel else { return }

        // For buy orders: set price to be below or equal to limit
        let adjustedPrice = limitPrice - 0.01 // Make it slightly below limit to ensure condition is met

        // Update the searchResult with the adjusted price
        var updatedResult = viewModel.searchResult
        updatedResult.askPrice = String(format: "%.2f", adjustedPrice).replacingOccurrences(of: ".", with: ",")
        viewModel.searchResult = updatedResult

        print("🔍 DEBUG: Price adjusted to \(adjustedPrice) to meet limit \(limitPrice)")

        // Start price validity timer
        viewModel.startPriceValidityTimer()
    }
}

// MARK: - Sell Order Monitor Implementation
class SellOrderMonitorImpl: LimitOrderMonitorImpl {
    private weak var sellOrderViewModel: SellOrderViewModel?

    init(sellOrderViewModel: SellOrderViewModel) {
        self.sellOrderViewModel = sellOrderViewModel
        super.init(monitor: sellOrderViewModel)
    }

    override func shouldExecuteLimitOrder(currentPrice: Double, limitPrice: Double) -> Bool {
        // For sell orders: execute when current price is above or equal to limit
        return currentPrice >= limitPrice
    }

    override func adjustPriceToMeetLimit(limitPrice: Double) {
        guard let viewModel = sellOrderViewModel else { return }

        // For sell orders: set price to be above or equal to limit
        let adjustedPrice = limitPrice + 0.01 // Make it slightly above limit to ensure condition is met

        // Update the current bid price
        viewModel.currentBidPrice = adjustedPrice

        print("🔍 DEBUG: Price adjusted to \(adjustedPrice) to meet limit \(limitPrice)")

        // Start price validity timer
        viewModel.startPriceValidityTimer()
    }
}
