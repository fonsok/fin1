import SwiftUI

// MARK: - Document Design System
/// Einheitliches Design-System für alle Trader/Investor-Dokumente
/// (Collection Bills, Invoices, Credit Notes, etc.)
struct DocumentDesignSystem {
    // MARK: - Background Colors

    /// Haupt-Hintergrundfarbe für Dokumente: #f5f5f5
    static let documentBackground = Color(hex: "#f5f5f5")

    /// Section-Hintergrundfarbe Level 1 (hellster Grauton)
    static let sectionBackground1 = Color(hex: "#f0f0f0")

    /// Section-Hintergrundfarbe Level 2 (mittlerer Grauton)
    static let sectionBackground2 = Color(hex: "#e8e8e8")

    /// Section-Hintergrundfarbe Level 3 (dunklerer Grauton)
    static let sectionBackground3 = Color(hex: "#e0e0e0")

    /// Section-Hintergrundfarbe Level 4 (dunkelster Grauton)
    static let sectionBackground4 = Color(hex: "#d8d8d8")

    // MARK: - Text Colors

    /// Haupt-Textfarbe: InputText Asset (#051221)
    static let textColor = Color("InputText")

    /// Sekundäre Textfarbe (70% Opacity)
    static var textColorSecondary: Color {
        textColor.opacity(0.7)
    }

    /// Tertiäre Textfarbe (50% Opacity)
    static var textColorTertiary: Color {
        textColor.opacity(0.5)
    }

    // MARK: - Helper Functions

    /// Gibt eine Section-Hintergrundfarbe basierend auf dem Index zurück
    /// - Parameter index: Index der Section (0-basiert)
    /// - Returns: Hintergrundfarbe für die Section
    static func sectionBackground(for index: Int) -> Color {
        switch index % 4 {
        case 0:
            return sectionBackground1
        case 1:
            return sectionBackground2
        case 2:
            return sectionBackground3
        default:
            return sectionBackground4
        }
    }

    /// Gibt eine Section-Hintergrundfarbe basierend auf dem Level zurück
    /// - Parameter level: Level der Section (1-4)
    /// - Returns: Hintergrundfarbe für die Section
    static func sectionBackground(level: Int) -> Color {
        switch level {
        case 1:
            return sectionBackground1
        case 2:
            return sectionBackground2
        case 3:
            return sectionBackground3
        case 4:
            return sectionBackground4
        default:
            return sectionBackground1
        }
    }
}

// MARK: - View Modifiers

extension View {
    /// Wendet das Dokument-Design auf eine Section an
    /// - Parameter level: Level der Section (1-4, optional)
    /// - Returns: View mit angewendetem Design
    func documentSection(level: Int = 1) -> some View {
        self
            .padding(ResponsiveDesign.spacing(16))
            .background(DocumentDesignSystem.sectionBackground(level: level))
            .cornerRadius(ResponsiveDesign.spacing(8))
    }

    /// Wendet das Dokument-Design auf den Haupt-Hintergrund an
    func documentBackground() -> some View {
        self
            .background(DocumentDesignSystem.documentBackground)
    }
}
