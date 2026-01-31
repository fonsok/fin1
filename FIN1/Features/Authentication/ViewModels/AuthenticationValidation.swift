import Foundation

// MARK: - Authentication Validation Service
/// Provides validation methods for authentication forms
struct AuthenticationValidation {

    // MARK: - Email Validation

    static func validateEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    // MARK: - Password Validation

    static func validatePassword(_ password: String) -> Bool {
        // At least 8 characters, 1 uppercase, 1 lowercase, 1 number
        let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)[a-zA-Z\\d@$!%*?&]{8,}$"
        let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        return passwordPredicate.evaluate(with: password)
    }

    static func getPasswordStrength(_ password: String) -> PasswordStrength {
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumbers = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecialChars = password.range(of: "[@$!%*?&]", options: .regularExpression) != nil
        let hasMinLength = password.count >= 8

        let strengthScore = [hasUppercase, hasLowercase, hasNumbers, hasSpecialChars, hasMinLength].filter { $0 }.count

        switch strengthScore {
        case 0...2: return .weak
        case 3...4: return .medium
        case 5: return .strong
        default: return .weak
        }
    }

    // MARK: - Form Validation

    static func validateLoginForm(email: String, password: String) -> (isValid: Bool, errorMessage: String?) {
        guard !email.isEmpty else {
            return (false, "Email is required")
        }

        guard !password.isEmpty else {
            return (false, "Password is required")
        }

        guard validateEmail(email) else {
            return (false, "Please enter a valid email address")
        }

        guard password.count >= 6 else {
            return (false, "Password must be at least 6 characters")
        }

        return (true, nil)
    }

    static func validateSignUpForm(userData: SignUpData) -> (isValid: Bool, errorMessage: String?) {
        guard !userData.email.isEmpty else {
            return (false, "Email is required")
        }

        guard !userData.password.isEmpty else {
            return (false, "Password is required")
        }

        guard validateEmail(userData.email) else {
            return (false, "Please enter a valid email address")
        }

        guard validatePassword(userData.password) else {
            return (false, "Password must be at least 8 characters with uppercase, lowercase, and numbers")
        }

        guard userData.password == userData.confirmPassword else {
            return (false, "Passwords do not match")
        }

        return (true, nil)
    }
}
