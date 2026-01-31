import Foundation

// MARK: - User Validation Service
/// Handles validation logic for user authentication and profile management
struct UserValidationService {

    // MARK: - Sign In Validation

    static func validateSignIn(email: String, password: String) throws {
        guard !email.isEmpty else {
            let error = AppError.validationError("Email is required")
            TelemetryService.shared.trackAppError(error, context: ErrorContext(screen: "Authentication", action: "signIn", additionalData: ["email_provided": false]))
            throw error
        }

        guard !password.isEmpty else {
            let error = AppError.validationError("Password is required")
            TelemetryService.shared.trackAppError(error, context: ErrorContext(screen: "Authentication", action: "signIn", additionalData: ["password_provided": false]))
            throw error
        }

        guard email.contains("@") else {
            let error = AppError.validationError("Please enter a valid email address")
            TelemetryService.shared.trackAppError(error, context: ErrorContext(screen: "Authentication", action: "signIn", additionalData: ["email_format": "invalid"]))
            throw error
        }

        guard password.count >= 6 else {
            let error = AppError.validationError("Password must be at least 6 characters")
            TelemetryService.shared.trackAppError(error, context: ErrorContext(screen: "Authentication", action: "signIn", additionalData: ["password_length": password.count]))
            throw error
        }
    }

    // MARK: - Sign Up Validation

    static func validateSignUp(userData: User) throws {
        guard !userData.email.isEmpty else {
            throw AppError.validationError("Email is required")
        }

        guard userData.email.contains("@") else {
            throw AppError.validationError("Please enter a valid email address")
        }

        guard !userData.password.isEmpty else {
            throw AppError.validationError("Password is required")
        }

        guard userData.password.count >= 8 else {
            throw AppError.validationError("Password must be at least 8 characters")
        }

        guard !userData.firstName.isEmpty else {
            throw AppError.validationError("First name is required")
        }

        guard !userData.lastName.isEmpty else {
            throw AppError.validationError("Last name is required")
        }
    }

    // MARK: - Profile Update Validation

    static func validateProfileUpdate(user: User) throws {
        guard !user.email.isEmpty else {
            throw AppError.validationError("Email is required")
        }

        guard user.email.contains("@") else {
            throw AppError.validationError("Please enter a valid email address")
        }

        guard !user.firstName.isEmpty else {
            throw AppError.validationError("First name is required")
        }

        guard !user.lastName.isEmpty else {
            throw AppError.validationError("Last name is required")
        }
    }

    // MARK: - Authentication Error Simulation

    static func checkForSimulatedErrors(email: String, password: String) throws {
        // Simulate authentication failure for certain emails
        if email.lowercased().contains("invalid") || email.lowercased().contains("wrong") {
            let error = AppError.authenticationError(.invalidCredentials)
            TelemetryService.shared.trackAppError(error, context: ErrorContext(screen: "Authentication", action: "signIn", additionalData: ["email": email, "test_scenario": "invalid_credentials"]))
            throw error
        }

        // Simulate account locked scenario
        if email.lowercased().contains("locked") {
            let error = AppError.authenticationError(.accountLocked)
            TelemetryService.shared.trackAppError(error, context: ErrorContext(screen: "Authentication", action: "signIn", additionalData: ["email": email, "test_scenario": "account_locked"]))
            throw error
        }
    }

    // MARK: - Sign Up Error Simulation

    static func checkForSignUpErrors(userData: User) throws {
        // Simulate email already exists error
        if userData.email.lowercased().contains("exists") || userData.email.lowercased().contains("duplicate") {
            throw AppError.authenticationError(.emailAlreadyExists)
        }

        // Simulate weak password error
        if userData.password.count < 8 || userData.password.lowercased() == "password" {
            throw AppError.authenticationError(.weakPassword)
        }
    }

    // MARK: - Profile Update Error Simulation

    static func checkForProfileUpdateErrors(user: User) throws {
        // Simulate permission denied error
        if user.email.lowercased().contains("permission") {
            throw AppError.serviceError(.permissionDenied)
        }
    }

    // MARK: - Refresh User Data Error Simulation

    static func checkForRefreshErrors(currentUser: User) throws {
        // Simulate network error
        if currentUser.email.lowercased().contains("network") {
            throw AppError.networkError(.noConnection)
        }

        // Simulate server error
        if currentUser.email.lowercased().contains("server") {
            throw AppError.networkError(.serverError(500))
        }
    }
}
