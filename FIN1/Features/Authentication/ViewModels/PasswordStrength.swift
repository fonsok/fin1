import SwiftUI

// MARK: - Password Strength Enum
enum PasswordStrength {
    case weak
    case medium
    case strong

    var color: Color {
        switch self {
        case .weak: return AppTheme.accentRed
        case .medium: return AppTheme.accentOrange
        case .strong: return AppTheme.accentGreen
        }
    }

    var description: String {
        switch self {
        case .weak: return "Add uppercase, lowercase, numbers, and special characters"
        case .medium: return "Add special characters and ensure 8+ characters"
        case .strong: return "Strong password"
        }
    }
}
