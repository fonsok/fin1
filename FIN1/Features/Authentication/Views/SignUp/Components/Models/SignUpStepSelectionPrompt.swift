import Foundation

/// Shared copy for unset step-15/16 pickers and related validation hints.
enum SignUpStepSelectionPrompt {
    /// Default list item and field label for unanswered dropdowns (steps 15 & 16).
    static let unsetOption = "Bitte wählen ..."

    /// Backward-compatible alias used by risk-class debug views.
    static let pleaseSelect = unsetOption

    static let incomeSources = "Bitte wählen Sie mindestens eine Einkommensquelle."
    static let otherAssets = "Bitte wählen Sie mindestens eine Option bei „Other assets“."
}
