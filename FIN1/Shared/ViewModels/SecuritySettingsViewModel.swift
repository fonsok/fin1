import Combine
import Foundation
import LocalAuthentication

// MARK: - Security Settings ViewModel
/// ViewModel for managing user security settings including authentication and 2FA
@MainActor
final class SecuritySettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    // Biometric Authentication
    @Published var biometricAuthEnabled: Bool = false
    @Published var biometricType: BiometricType = .none
    @Published var isBiometricAvailable: Bool = false

    // Two-Factor Authentication
    @Published var twoFactorEnabled: Bool = false
    @Published var twoFactorMethod: TwoFactorMethod = .sms
    @Published var showTwoFactorSetup: Bool = false

    // Password & Login
    @Published var requirePasswordOnLaunch: Bool = true
    @Published var autoLockTimeout: AutoLockTimeout = .fiveMinutes
    @Published var showPasswordChange: Bool = false

    // Session Security
    @Published var showActiveSessionsAlert: Bool = false
    @Published var loginAlertsEnabled: Bool = true
    @Published var rememberDevice: Bool = true

    // Password Change
    @Published var currentPassword: String = ""
    @Published var newPassword: String = ""
    @Published var confirmPassword: String = ""
    @Published var passwordChangeError: String?
    @Published var isChangingPassword: Bool = false
    @Published var showPasswordChangeSuccess: Bool = false

    // Activity Log
    @Published var showSecurityActivityLog: Bool = false
    @Published var recentSecurityEvents: [SecurityEvent] = []

    // MARK: - Private Properties

    private let userService: any UserServiceProtocol
    private let userDefaultsKey = "FIN1_SecuritySettings"
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(userService: any UserServiceProtocol) {
        self.userService = userService
        self.checkBiometricAvailability()
        self.loadSettings()
        self.loadMockSecurityEvents()
    }

    // MARK: - Public Methods

    /// Saves all security settings to persistent storage
    func saveSettings() {
        let settings = SecuritySettings(
            biometricAuthEnabled: biometricAuthEnabled,
            twoFactorEnabled: twoFactorEnabled,
            twoFactorMethod: twoFactorMethod,
            requirePasswordOnLaunch: requirePasswordOnLaunch,
            autoLockTimeout: autoLockTimeout,
            loginAlertsEnabled: loginAlertsEnabled,
            rememberDevice: rememberDevice
        )

        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: self.userDefaultsKey)
        }
    }

    /// Enables biometric authentication after verification
    func enableBiometricAuth() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Enable biometric login for \(AppBrand.appName)"
        ) { [weak self] success, _ in
            Task { @MainActor [weak self] in
                if success {
                    self?.biometricAuthEnabled = true
                    self?.saveSettings()
                }
            }
        }
    }

    /// Disables biometric authentication
    func disableBiometricAuth() {
        self.biometricAuthEnabled = false
        self.saveSettings()
    }

    /// Validates and changes the user password
    func changePassword() {
        self.passwordChangeError = nil

        guard !self.currentPassword.isEmpty else {
            self.passwordChangeError = "Please enter your current password"
            return
        }

        guard self.newPassword.count >= 8 else {
            self.passwordChangeError = "New password must be at least 8 characters"
            return
        }

        guard self.newPassword == self.confirmPassword else {
            self.passwordChangeError = "New passwords do not match"
            return
        }

        guard self.newPassword != self.currentPassword else {
            self.passwordChangeError = "New password must be different from current password"
            return
        }

        self.isChangingPassword = true

        Task { @MainActor [weak self] in
            // Simulate password change API call
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self?.isChangingPassword = false
            self?.showPasswordChangeSuccess = true
            self?.clearPasswordFields()
            self?.showPasswordChange = false
        }
    }

    /// Terminates all other active sessions
    func terminateAllSessions() {
        self.recentSecurityEvents.insert(
            SecurityEvent(
                id: UUID().uuidString,
                type: .sessionTerminated,
                description: "All other sessions terminated",
                timestamp: Date(),
                location: nil
            ),
            at: 0
        )
    }

    /// Resets security settings to defaults
    func resetToDefaults() {
        self.biometricAuthEnabled = false
        self.twoFactorEnabled = false
        self.twoFactorMethod = .sms
        self.requirePasswordOnLaunch = true
        self.autoLockTimeout = .fiveMinutes
        self.loginAlertsEnabled = true
        self.rememberDevice = true
    }

    // MARK: - Private Methods

    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?

        self.isBiometricAvailable = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )

        switch context.biometryType {
        case .faceID:
            self.biometricType = .faceID
        case .touchID:
            self.biometricType = .touchID
        case .opticID:
            self.biometricType = .opticID
        case .none:
            self.biometricType = .none
        @unknown default:
            self.biometricType = .none
        }
    }

    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let settings = try? JSONDecoder().decode(SecuritySettings.self, from: data) else {
            return
        }

        self.biometricAuthEnabled = settings.biometricAuthEnabled && self.isBiometricAvailable
        self.twoFactorEnabled = settings.twoFactorEnabled
        self.twoFactorMethod = settings.twoFactorMethod
        self.requirePasswordOnLaunch = settings.requirePasswordOnLaunch
        self.autoLockTimeout = settings.autoLockTimeout
        self.loginAlertsEnabled = settings.loginAlertsEnabled
        self.rememberDevice = settings.rememberDevice
    }

    private func clearPasswordFields() {
        self.currentPassword = ""
        self.newPassword = ""
        self.confirmPassword = ""
        self.passwordChangeError = nil
    }

    private func loadMockSecurityEvents() {
        self.recentSecurityEvents = [
            SecurityEvent(
                id: "1",
                type: .login,
                description: "Successful login",
                timestamp: Date().addingTimeInterval(-3_600),
                location: "San Francisco, CA"
            ),
            SecurityEvent(
                id: "2",
                type: .passwordChanged,
                description: "Password was changed",
                timestamp: Date().addingTimeInterval(-86_400 * 3),
                location: nil
            ),
            SecurityEvent(
                id: "3",
                type: .twoFactorEnabled,
                description: "Two-factor authentication enabled",
                timestamp: Date().addingTimeInterval(-86_400 * 7),
                location: nil
            ),
            SecurityEvent(
                id: "4",
                type: .login,
                description: "Successful login",
                timestamp: Date().addingTimeInterval(-86_400 * 10),
                location: "New York, NY"
            )
        ]
    }
}
