import Foundation

// MARK: - Investor collection bill local calculation gate (ADR-019 Phase 2)

/// Guards `InvestorCollectionBillCalculationService.calculateCollectionBill` — production uses server Beleg metadata only.
enum InvestorCollectionBillLocalCalculationGate {
    nonisolated(unsafe) private(set) static var isPermitted = false

    static func withPermitted<T>(_ operation: () throws -> T) rethrows -> T {
        self.isPermitted = true
        defer { self.isPermitted = false }
        return try operation()
    }

    static func withPermitted<T>(_ operation: () async throws -> T) async rethrows -> T {
        self.isPermitted = true
        defer { self.isPermitted = false }
        return try await operation()
    }

    static func requirePermitted(file: StaticString = #file, line: UInt = #line) {
        guard self.isPermitted else {
            preconditionFailure(
                "Investor collection bill local calculation is disabled in production. "
                    + "Use server Beleg metadata or InvestorCollectionBillLocalCalculationGate.withPermitted in tests.",
                file: file,
                line: line
            )
        }
    }
}
