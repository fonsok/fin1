import Foundation

// MARK: - Permission Category
/// Categories for grouping permissions in the UI
enum PermissionCategory: String, CaseIterable, Codable {
    case viewing
    case modification
    case support
    case compliance
    case fraud
    case administration

    var displayName: String {
        switch self {
        case .viewing: return "Ansicht"
        case .modification: return "Bearbeitung"
        case .support: return "Support"
        case .compliance: return "Compliance"
        case .fraud: return "Betrugsbekämpfung"
        case .administration: return "Administration"
        }
    }

    var icon: String {
        switch self {
        case .viewing: return "eye.fill"
        case .modification: return "pencil.circle.fill"
        case .support: return "bubble.left.and.bubble.right.fill"
        case .compliance: return "checkmark.shield.fill"
        case .fraud: return "exclamationmark.shield.fill"
        case .administration: return "gearshape.2.fill"
        }
    }
}
