import XCTest
@testable import FIN1

class ErrorHandlingTests: XCTestCase {
    var mockTelemetryService: MockTelemetryService!

    override func setUp() {
        super.setUp()
        mockTelemetryService = MockTelemetryService()
    }

    override func tearDown() {
        mockTelemetryService = nil
        super.tearDown()
    }

    // MARK: - AppError Tests

    func testAppErrorValidation() {
        // Given
        let message = "Email is required"
        let error = AppError.validationError(message)

        // Then
        XCTAssertEqual(error.localizedDescription, message)
        XCTAssertEqual(error.recoverySuggestion, "Please check your input and try again.")

        switch error {
        case .validation(let errorMessage):
            XCTAssertEqual(errorMessage, message)
        default:
            XCTFail("Expected validation error")
        }
    }

    func testAppErrorNetwork() {
        // Given
        let networkError = NetworkError.noConnection
        let error = AppError.networkError(networkError)

        // Then
        XCTAssertEqual(error.localizedDescription, "No internet connection")
        XCTAssertEqual(error.recoverySuggestion, "Please check your internet connection and try again.")

        switch error {
        case .network(let error):
            XCTAssertEqual(error, .noConnection)
        default:
            XCTFail("Expected network error")
        }
    }

    func testAppErrorAuthentication() {
        // Given
        let authError = AuthError.invalidCredentials
        let error = AppError.authenticationError(authError)

        // Then
        XCTAssertEqual(error.localizedDescription, "Invalid email or password")
        XCTAssertEqual(error.recoverySuggestion, "Please check your credentials and try again.")

        switch error {
        case .authentication(let error):
            XCTAssertEqual(error, .invalidCredentials)
        default:
            XCTFail("Expected authentication error")
        }
    }

    func testAppErrorService() {
        // Given
        let serviceError = ServiceError.dataNotFound
        let error = AppError.serviceError(serviceError)

        // Then
        XCTAssertEqual(error.localizedDescription, "Requested data not found")
        XCTAssertEqual(error.recoverySuggestion, "Please try again later or contact support if the problem persists.")

        switch error {
        case .service(let error):
            XCTAssertEqual(error, .dataNotFound)
        default:
            XCTFail("Expected service error")
        }
    }

    func testAppErrorUnknown() {
        // Given
        let message = "Unknown error occurred"
        let error = AppError.unknownError(message)

        // Then
        XCTAssertEqual(error.localizedDescription, message)
        XCTAssertEqual(error.recoverySuggestion, "Please try again or contact support if the problem persists.")

        switch error {
        case .unknown(let errorMessage):
            XCTAssertEqual(errorMessage, message)
        default:
            XCTFail("Expected unknown error")
        }
    }

    // MARK: - ErrorContext Tests

    func testErrorContextInitialization() {
        // Given
        let screen = "Authentication"
        let action = "signIn"
        let userId = "user123"
        let userRole = "Investor"
        let additionalData = ["email": "test@example.com"]

        // When
        let context = ErrorContext(
            screen: screen,
            action: action,
            userId: userId,
            userRole: userRole,
            additionalData: additionalData
        )

        // Then
        XCTAssertEqual(context.screen, screen)
        XCTAssertEqual(context.action, action)
        XCTAssertEqual(context.userId, userId)
        XCTAssertEqual(context.userRole, userRole)
        XCTAssertEqual(context.additionalData?["email"] as? String, "test@example.com")
        XCTAssertNotNil(context.timestamp)
    }

    func testErrorContextWithOptionalParameters() {
        // Given
        let screen = "Dashboard"

        // When
        let context = ErrorContext(screen: screen)

        // Then
        XCTAssertEqual(context.screen, screen)
        XCTAssertNil(context.action)
        XCTAssertNil(context.userId)
        XCTAssertNil(context.userRole)
        XCTAssertNil(context.additionalData)
        XCTAssertNotNil(context.timestamp)
    }

    // MARK: - TelemetryService Error Tracking Tests

    func testTrackAppError() {
        // Given
        let error = AppError.validationError("Email is required")
        let context = ErrorContext(
            screen: "Authentication",
            action: "signIn",
            userId: "user123",
            userRole: "Investor",
            additionalData: ["email_provided": false]
        )

        // When
        mockTelemetryService.trackAppError(error, context: context)

        // Then
        XCTAssertEqual(mockTelemetryService.trackedAppErrors.count, 1)
        guard let trackedError = mockTelemetryService.trackedAppErrors.first else {
            XCTFail("Expected at least one tracked error")
            return
        }
        XCTAssertEqual(trackedError.error.localizedDescription, "Email is required")
        XCTAssertEqual(trackedError.context?.screen, "Authentication")
        XCTAssertEqual(trackedError.context?.action, "signIn")
        XCTAssertEqual(trackedError.context?.userId, "user123")
        XCTAssertEqual(trackedError.context?.userRole, "Investor")
    }

    func testTrackMultipleAppErrors() {
        // Given
        let error1 = AppError.validationError("Email is required")
        let error2 = AppError.networkError(.noConnection)
        let context1 = ErrorContext(screen: "Authentication", action: "signIn")
        let context2 = ErrorContext(screen: "Dashboard", action: "loadData")

        // When
        mockTelemetryService.trackAppError(error1, context: context1)
        mockTelemetryService.trackAppError(error2, context: context2)

        // Then
        XCTAssertEqual(mockTelemetryService.trackedAppErrors.count, 2)
        XCTAssertEqual(mockTelemetryService.trackedAppErrors[0].context?.screen, "Authentication")
        XCTAssertEqual(mockTelemetryService.trackedAppErrors[1].context?.screen, "Dashboard")
    }

    func testTrackAppErrorWithoutContext() {
        // Given
        let error = AppError.unknownError("Test error")

        // When
        mockTelemetryService.trackAppError(error, context: nil)

        // Then
        XCTAssertEqual(mockTelemetryService.trackedAppErrors.count, 1)
        guard let trackedError = mockTelemetryService.trackedAppErrors.first else {
            XCTFail("Expected at least one tracked error")
            return
        }
        XCTAssertEqual(trackedError.error.localizedDescription, "Test error")
        XCTAssertNil(trackedError.context)
    }

    // MARK: - Error Recovery Tests

    func testValidationErrorRecovery() {
        // Given
        let error = AppError.validationError("Password must be at least 8 characters")

        // Then
        XCTAssertEqual(error.recoverySuggestion, "Please check your input and try again.")
    }

    func testNetworkErrorRecovery() {
        // Given
        let error = AppError.networkError(.timeout)

        // Then
        XCTAssertEqual(error.recoverySuggestion, "Please check your internet connection and try again.")
    }

    func testAuthenticationErrorRecovery() {
        // Given
        let error = AppError.authenticationError(.accountLocked)

        // Then
        XCTAssertEqual(error.recoverySuggestion, "Please contact support to unlock your account.")
    }

    func testServiceErrorRecovery() {
        // Given
        let error = AppError.serviceError(.rateLimited)

        // Then
        XCTAssertEqual(error.recoverySuggestion, "Please wait a moment and try again.")
    }

    // MARK: - Error Categorization Tests

    func testErrorTypeCategorization() {
        // Given
        let validationError = AppError.validationError("Email is required")
        let networkError = AppError.networkError(.noConnection)
        let authError = AppError.authenticationError(.invalidCredentials)
        let serviceError = AppError.serviceError(.dataNotFound)
        let unknownError = AppError.unknownError("Unknown error")

        // Then
        XCTAssertEqual(validationError.errorType, "validation")
        XCTAssertEqual(networkError.errorType, "network")
        XCTAssertEqual(authError.errorType, "authentication")
        XCTAssertEqual(serviceError.errorType, "service")
        XCTAssertEqual(unknownError.errorType, "unknown")
    }

    func testErrorCategoryCategorization() {
        // Given
        let emailValidationError = AppError.validationError("Email is required")
        let passwordValidationError = AppError.validationError("Password is too short")
        let noConnectionError = AppError.networkError(.noConnection)
        let timeoutError = AppError.networkError(.timeout)
        let invalidCredentialsError = AppError.authenticationError(.invalidCredentials)
        let accountLockedError = AppError.authenticationError(.accountLocked)

        // Then
        XCTAssertEqual(emailValidationError.errorCategory, "email_validation")
        XCTAssertEqual(passwordValidationError.errorCategory, "input_validation")
        XCTAssertEqual(noConnectionError.errorCategory, "no_connection")
        XCTAssertEqual(timeoutError.errorCategory, "timeout")
        XCTAssertEqual(invalidCredentialsError.errorCategory, "invalid_credentials")
        XCTAssertEqual(accountLockedError.errorCategory, "account_locked")
    }

    // MARK: - Error Tracking Reset Tests

    func testTelemetryServiceReset() {
        // Given
        mockTelemetryService.trackAppError(AppError.unknownError("Test error"), context: nil)
        mockTelemetryService.trackEvent(name: "test_event", properties: nil)
        mockTelemetryService.setUser(id: "user123", role: "Investor")

        // When
        mockTelemetryService.reset()

        // Then
        XCTAssertEqual(mockTelemetryService.trackedAppErrors.count, 0)
        XCTAssertEqual(mockTelemetryService.trackedEvents.count, 0)
        XCTAssertEqual(mockTelemetryService.trackedErrors.count, 0)
        XCTAssertNil(mockTelemetryService.userInfo.id)
        XCTAssertNil(mockTelemetryService.userInfo.role)
    }
}

// MARK: - AppError Extensions for Testing

extension AppError {
    var errorType: String {
        switch self {
        case .validation: return "validation"
        case .network: return "network"
        case .authentication: return "authentication"
        case .service: return "service"
        case .unknown: return "unknown"
        }
    }

    var errorCategory: String {
        switch self {
        case .validation(let message):
            return message.contains("email") ? "email_validation" : "input_validation"
        case .network(let networkError):
            switch networkError {
            case .noConnection: return "no_connection"
            case .timeout: return "timeout"
            case .serverError: return "server_error"
            case .invalidResponse: return "invalid_response"
            case .decodingError: return "decoding_error"
            }
        case .authentication(let authError):
            switch authError {
            case .invalidCredentials: return "invalid_credentials"
            case .userNotFound: return "user_not_found"
            case .accountLocked: return "account_locked"
            case .emailNotVerified: return "email_not_verified"
            case .weakPassword: return "weak_password"
            case .emailAlreadyExists: return "email_already_exists"
            }
        case .service(let serviceError):
            switch serviceError {
            case .dataNotFound: return "data_not_found"
            case .invalidData: return "invalid_data"
            case .operationFailed: return "operation_failed"
            case .permissionDenied: return "permission_denied"
            case .rateLimited: return "rate_limited"
            case .serviceUnavailable: return "service_unavailable"
            case .configurationError: return "configuration_error"
            case .timeout: return "timeout"
            }
        case .unknown: return "unknown_error"
        }
    }
}
