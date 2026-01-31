import SwiftUI

// MARK: - Input Field Validation
/// Validation logic and enums for UnifiedInputField

// MARK: - Validation State
/// Represents the validation state of an input field
enum ValidationState {
    case none
    case valid
    case invalid(String)
    case warning(String)
}

// MARK: - Validation Message View
/// Displays validation messages with appropriate styling
struct ValidationMessageView: View {
    let validationState: ValidationState

    var body: some View {
        Group {
            switch validationState {
            case .none:
                EmptyView()
            case .valid:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Valid")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.green)
                }
            case .invalid(let message):
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(AppTheme.accentRed)
                    Text(message)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentRed)
                }
            case .warning(let message):
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(message)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

// MARK: - Input Field Validation Extensions
extension UnifiedInputField {

    /// Validates email format
    static func validateEmail(_ email: String) -> ValidationState {
        if email.isEmpty {
            return .none
        }

        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        if emailPredicate.evaluate(with: email) {
            return .valid
        } else {
            return .invalid("Please enter a valid email address")
        }
    }

    /// Validates password strength
    static func validatePassword(_ password: String) -> ValidationState {
        if password.isEmpty {
            return .none
        }

        if password.count < 8 {
            return .invalid("Password must be at least 8 characters long")
        }

        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasDigit = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecialChar = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil

        if hasUppercase && hasLowercase && hasDigit && hasSpecialChar {
            return .valid
        } else {
            return .warning("Password should contain uppercase, lowercase, digit, and special character")
        }
    }

    /// Validates phone number format
    static func validatePhone(_ phone: String) -> ValidationState {
        if phone.isEmpty {
            return .none
        }

        let phoneRegex = "^[+]?[0-9\\s\\-\\(\\)]{10,}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)

        if phonePredicate.evaluate(with: phone) {
            return .valid
        } else {
            return .invalid("Please enter a valid phone number")
        }
    }

    /// Validates required field
    static func validateRequired(_ text: String, fieldName: String) -> ValidationState {
        if text.isEmpty {
            return .invalid("\(fieldName) is required")
        } else {
            return .valid
        }
    }

    /// Validates text length
    static func validateLength(_ text: String, minLength: Int? = nil, maxLength: Int? = nil, fieldName: String) -> ValidationState {
        if let minLength = minLength, text.count < minLength {
            return .invalid("\(fieldName) must be at least \(minLength) characters long")
        }

        if let maxLength = maxLength, text.count > maxLength {
            return .invalid("\(fieldName) must be no more than \(maxLength) characters long")
        }

        return .valid
    }
}
