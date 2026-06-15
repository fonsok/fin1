import Foundation

// MARK: - Invoice local synthesis gate (GoB P3b)

/// Guards `Invoice.from(...)` order/trade synthesis — production uses backend `Invoice` records only.
enum InvoiceLocalSynthesisGate {
    nonisolated(unsafe) private(set) static var isPermitted = false

    /// Wrap test/dev code that may call `Invoice.from` for order/trade synthesis.
    static func withPermitted<T>(_ operation: () throws -> T) rethrows -> T {
        self.isPermitted = true
        defer { self.isPermitted = false }
        return try operation()
    }

    /// Async variant for invoice backfill paths that call `await` inside synthesis.
    static func withPermitted<T>(_ operation: () async throws -> T) async rethrows -> T {
        self.isPermitted = true
        defer { self.isPermitted = false }
        return try await operation()
    }

    static func requirePermitted(file: StaticString = #file, line: UInt = #line) {
        guard self.isPermitted else {
            preconditionFailure(
                "Invoice.from local synthesis is disabled (P3b). Use backend Invoice records or InvoiceLocalSynthesisGate.withPermitted in tests.",
                file: file,
                line: line
            )
        }
    }
}

enum InvoiceLocalSynthesisError: LocalizedError {
    case disabledInProduction

    var errorDescription: String? {
        switch self {
        case .disabledInProduction:
            return "Lokale Rechnungserstellung ist deaktiviert. Rechnungen kommen vom Server (Server-only)."
        }
    }
}
