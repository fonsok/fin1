import Foundation

// MARK: - Security Settings Models
/// Models for security settings functionality

// MARK: - Biometric Type

enum BiometricType: String, Codable {
    case faceID = "Face ID"
    case touchID = "Touch ID"
    case opticID = "Optic ID"
    case none = "None"

    var iconName: String {
        switch self {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        case .none: return "lock.fill"
        }
    }
}

// MARK: - Two-Factor Method

enum TwoFactorMethod: String, Codable, CaseIterable {
    case sms = "SMS"
    case email = "Email"
    case authenticatorApp = "Authenticator App"

    var iconName: String {
        switch self {
        case .sms: return "message.fill"
        case .email: return "envelope.fill"
        case .authenticatorApp: return "key.fill"
        }
    }
}

// MARK: - Auto-Lock Timeout

enum AutoLockTimeout: String, Codable, CaseIterable {
    case immediately = "Immediately"
    case oneMinute = "1 Minute"
    case fiveMinutes = "5 Minutes"
    case fifteenMinutes = "15 Minutes"
    case thirtyMinutes = "30 Minutes"
    case never = "Never"

    var seconds: Int {
        switch self {
        case .immediately: return 0
        case .oneMinute: return 60
        case .fiveMinutes: return 300
        case .fifteenMinutes: return 900
        case .thirtyMinutes: return 1800
        case .never: return -1
        }
    }
}

// MARK: - Security Event

struct SecurityEvent: Identifiable {
    let id: String
    let type: SecurityEventType
    let description: String
    let timestamp: Date
    let location: String?
}

// MARK: - Security Event Type

enum SecurityEventType {
    case login
    case logout
    case passwordChanged
    case twoFactorEnabled
    case twoFactorDisabled
    case sessionTerminated
    case failedLogin

    var iconName: String {
        switch self {
        case .login: return "person.badge.key.fill"
        case .logout: return "rectangle.portrait.and.arrow.right.fill"
        case .passwordChanged: return "key.fill"
        case .twoFactorEnabled: return "shield.checkered"
        case .twoFactorDisabled: return "shield.slash.fill"
        case .sessionTerminated: return "xmark.circle.fill"
        case .failedLogin: return "exclamationmark.triangle.fill"
        }
    }

    var color: String {
        switch self {
        case .login, .twoFactorEnabled: return "green"
        case .logout, .sessionTerminated: return "orange"
        case .passwordChanged: return "blue"
        case .twoFactorDisabled, .failedLogin: return "red"
        }
    }
}

// MARK: - Security Settings (Persistence)

struct SecuritySettings: Codable {
    let biometricAuthEnabled: Bool
    let twoFactorEnabled: Bool
    let twoFactorMethod: TwoFactorMethod
    let requirePasswordOnLaunch: Bool
    let autoLockTimeout: AutoLockTimeout
    let loginAlertsEnabled: Bool
    let rememberDevice: Bool
}





