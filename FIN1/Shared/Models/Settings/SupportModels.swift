import Foundation

// MARK: - Support Models
/// Models for contact support functionality

// MARK: - Support Category

enum SupportCategory: String, CaseIterable, Identifiable {
    case general = "General Inquiry"
    case accountIssue = "Account Issue"
    case technicalIssue = "Technical Problem"
    case billing = "Billing & Payments"
    case investment = "Investment Question"
    case tradingQuestion = "Trading Question"
    case security = "Security Concern"
    case feedback = "Feedback & Suggestions"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "questionmark.circle.fill"
        case .accountIssue: return "person.crop.circle.badge.exclamationmark.fill"
        case .technicalIssue: return "wrench.and.screwdriver.fill"
        case .billing: return "creditcard.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .tradingQuestion: return "arrow.up.arrow.down.circle.fill"
        case .security: return "lock.shield.fill"
        case .feedback: return "star.bubble.fill"
        }
    }

    var color: String {
        switch self {
        case .general: return "blue"
        case .accountIssue: return "orange"
        case .technicalIssue: return "purple"
        case .billing: return "green"
        case .investment: return "cyan"
        case .tradingQuestion: return "indigo"
        case .security: return "red"
        case .feedback: return "yellow"
        }
    }

    var priority: SupportPriority {
        switch self {
        case .security, .accountIssue: return .high
        case .technicalIssue, .billing: return .medium
        case .general, .investment, .tradingQuestion, .feedback: return .normal
        }
    }
}

// MARK: - Support Priority

enum SupportPriority: String {
    case high = "High"
    case medium = "Medium"
    case normal = "Normal"

    var color: String {
        switch self {
        case .high: return "red"
        case .medium: return "orange"
        case .normal: return "green"
        }
    }
}





