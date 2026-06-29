import Foundation

// MARK: - Buy order placement phase (explicit UI / transmission state)

enum BuyOrderPhase {
    case editing
    case placing(BuyOrderPlacementSnapshot)
    case failed(AppError)

    var isEditing: Bool {
        if case .editing = self { return true }
        return false
    }

    var isPlacing: Bool {
        if case .placing = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    /// Placement may start from editing or after a surfaced failure (retry with a fresh intent).
    var canStartPlacement: Bool {
        self.isEditing || self.isFailed
    }

    var lockedQuantity: Int? {
        if case .placing(let snapshot) = self { return snapshot.quantity }
        return nil
    }
}

struct BuyOrderPlacementSnapshot {
    let quantity: Int
    let searchResult: SearchResult
    let orderMode: OrderMode
    let limit: String
    let priceValidityProgress: Double
    let investmentOrderCalculation: CombinedOrderCalculationResult?
    let clientOrderIntentId: String
}

struct BuyOrderPlacementSession {
    var phase: BuyOrderPhase = .editing
    private(set) var pendingClientOrderIntentId: String?

    var isInputLocked: Bool { self.phase.isPlacing }

    var lockedQuantity: Int? { self.phase.lockedQuantity }

    var buyOrderStatus: BuyOrderStatus {
        switch self.phase {
        case .editing:
            return .idle
        case .placing:
            return .transmitting
        case .failed(let error):
            return .failed(error)
        }
    }

    mutating func ensureClientOrderIntentId() -> String {
        if let existing = pendingClientOrderIntentId {
            return existing
        }
        let newId = UUID().uuidString
        self.pendingClientOrderIntentId = newId
        return newId
    }

    mutating func beginPlacing(_ snapshot: BuyOrderPlacementSnapshot) {
        self.phase = .placing(snapshot)
    }

    mutating func completeSuccess() {
        self.pendingClientOrderIntentId = nil
        self.phase = .editing
    }

    mutating func completeFailure(_ error: AppError) {
        self.phase = .failed(error)
    }

    mutating func acknowledgeFailure() {
        self.pendingClientOrderIntentId = nil
        self.phase = .editing
    }

    mutating func resetToEditing() {
        self.phase = .editing
    }
}
