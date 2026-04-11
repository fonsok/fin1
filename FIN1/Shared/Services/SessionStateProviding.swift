import Foundation

/// Optional capability protocol for API clients that can indicate authenticated session state.
/// This keeps services backend-swappable without relying on concrete types.
protocol SessionStateProviding {
    var hasAuthenticatedSession: Bool { get }
}

