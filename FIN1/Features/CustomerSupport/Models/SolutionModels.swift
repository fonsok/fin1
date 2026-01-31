import Foundation

// MARK: - Solution Details

struct SolutionDetails: Codable {
    let solutionType: SolutionType
    let helpCenterArticleId: String?
    let helpCenterArticleTitle: String?
    let configurationChanges: [ConfigurationChange]?
    let devEscalation: DevEscalation?
    let workaround: String?
    let verificationSteps: [String]
    let customerConfirmed: Bool

    init(
        solutionType: SolutionType,
        helpCenterArticleId: String? = nil,
        helpCenterArticleTitle: String? = nil,
        configurationChanges: [ConfigurationChange]? = nil,
        devEscalation: DevEscalation? = nil,
        workaround: String? = nil,
        verificationSteps: [String] = [],
        customerConfirmed: Bool = false
    ) {
        self.solutionType = solutionType
        self.helpCenterArticleId = helpCenterArticleId
        self.helpCenterArticleTitle = helpCenterArticleTitle
        self.configurationChanges = configurationChanges
        self.devEscalation = devEscalation
        self.workaround = workaround
        self.verificationSteps = verificationSteps
        self.customerConfirmed = customerConfirmed
    }
}

// MARK: - Solution Type

enum SolutionType: String, Codable, CaseIterable {
    case helpCenterArticle    // Known answer from Help Center
    case configurationChange  // Adjusted configuration in app
    case devEscalation        // Bug escalated to Dev team
    case manualResolution     // Manually resolved by CSR
    case noActionRequired     // Issue resolved itself / not reproducible

    var displayName: String {
        switch self {
        case .helpCenterArticle: return "Help Center Artikel"
        case .configurationChange: return "Konfigurationsänderung"
        case .devEscalation: return "Eskalation an Entwicklung"
        case .manualResolution: return "Manuelle Lösung"
        case .noActionRequired: return "Keine Aktion erforderlich"
        }
    }

    var description: String {
        switch self {
        case .helpCenterArticle:
            return "Bekannte Lösung aus dem Help Center"
        case .configurationChange:
            return "Einstellung im System angepasst"
        case .devEscalation:
            return "Problem an Entwicklungsteam weitergeleitet"
        case .manualResolution:
            return "Manuell durch Support gelöst"
        case .noActionRequired:
            return "Problem hat sich von selbst gelöst"
        }
    }

    var icon: String {
        switch self {
        case .helpCenterArticle: return "book.fill"
        case .configurationChange: return "gearshape.fill"
        case .devEscalation: return "ladybug.fill"
        case .manualResolution: return "wrench.and.screwdriver.fill"
        case .noActionRequired: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Configuration Change

struct ConfigurationChange: Codable, Identifiable {
    let id: String
    let settingName: String
    let previousValue: String?
    let newValue: String
    let changedAt: Date
    let reason: String

    init(
        id: String = UUID().uuidString,
        settingName: String,
        previousValue: String? = nil,
        newValue: String,
        changedAt: Date = Date(),
        reason: String
    ) {
        self.id = id
        self.settingName = settingName
        self.previousValue = previousValue
        self.newValue = newValue
        self.changedAt = changedAt
        self.reason = reason
    }
}

// MARK: - Dev Escalation

struct DevEscalation: Codable {
    let jiraTicketId: String?
    let severity: BugSeverity
    let description: String
    let stepsToReproduce: [String]
    let expectedBehavior: String
    let actualBehavior: String
    let affectedCustomers: Int
    let workaroundProvided: Bool
    let escalatedAt: Date
    let devTeam: String
}

// MARK: - Bug Severity

enum BugSeverity: String, Codable, CaseIterable {
    case critical   // System down, no workaround
    case high       // Major feature broken, workaround exists
    case medium     // Feature partially broken
    case low        // Minor issue, cosmetic

    var displayName: String {
        switch self {
        case .critical: return "Kritisch"
        case .high: return "Hoch"
        case .medium: return "Mittel"
        case .low: return "Niedrig"
        }
    }

    var color: String {
        switch self {
        case .critical: return "red"
        case .high: return "orange"
        case .medium: return "yellow"
        case .low: return "green"
        }
    }
}

