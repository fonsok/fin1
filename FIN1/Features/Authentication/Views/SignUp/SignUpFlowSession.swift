import Foundation

/// Tracks an in-flight sign-up started from the landing page so auth transitions
/// do not spawn a second `SignUpView` or re-trigger resume presentation.
@MainActor
enum SignUpFlowSession {
    private(set) static var isPresentingFromLanding = false
    /// User explicitly left onboarding (Cancel / session end). Blocks auto-resume loops.
    private(set) static var userLeftOnboarding = false

    static func beginFromLanding() {
        self.isPresentingFromLanding = true
        self.userLeftOnboarding = false
    }

    static func markUserLeftOnboarding() {
        self.userLeftOnboarding = true
    }

    static func resumeAfterExplicitPause() {
        self.userLeftOnboarding = false
    }

    static func end() {
        self.isPresentingFromLanding = false
    }

    static func reset() {
        self.isPresentingFromLanding = false
        self.userLeftOnboarding = false
    }
}
