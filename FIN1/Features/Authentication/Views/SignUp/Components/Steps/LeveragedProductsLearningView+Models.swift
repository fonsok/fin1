import SwiftUI

// MARK: - Scroll anchors

enum LearningAnchor: String, CaseIterable, Identifiable {
    case basics
    case call
    case put
    case formulas
    case examples
    case metrics
    case risks
    case note

    var id: String { rawValue }

    static var chipAnchors: [LearningAnchor] {
        [.basics, .call, .put, .formulas, .examples, .risks]
    }

    var chipTitle: String {
        switch self {
        case .basics: return "Grundlagen"
        case .call: return "Call"
        case .put: return "Put"
        case .formulas: return "Formeln"
        case .examples: return "Beispiele"
        case .metrics: return "Kennzahlen"
        case .risks: return "Risiken"
        case .note: return "Hinweis"
        }
    }

    var icon: String {
        switch self {
        case .basics: return "book.closed.fill"
        case .call: return "arrow.up.right"
        case .put: return "arrow.down.right"
        case .formulas: return "function"
        case .examples: return "list.number"
        case .metrics: return "gauge.with.dots.needle.67percent"
        case .risks: return "exclamationmark.triangle"
        case .note: return "clock.badge.exclamationmark"
        }
    }

    var accentColor: Color {
        switch self {
        case .basics, .formulas, .metrics, .note: return AppTheme.accentLightBlue
        case .call, .examples: return AppTheme.accentGreen
        case .put, .risks: return AppTheme.accentOrange
        }
    }
}

// MARK: - Scenario model

struct LearningScenarioItem: Identifiable {
    enum Tone {
        case gain
        case loss
    }

    let id = UUID()
    let title: String
    let tone: Tone
    let text: String
}
