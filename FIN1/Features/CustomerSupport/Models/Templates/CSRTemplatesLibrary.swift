import Foundation

// MARK: - CSR Response Templates Library
/// Central access point for role-specific response templates
struct CSRTemplatesLibrary {

    // MARK: - Get Templates for Role

    static func templates(for role: CSRRole) -> [ResponseTemplate] {
        allTemplates.filter { $0.availableForRoles.contains(role) }
    }

    static func templates(for role: CSRRole, category: TemplateCategory) -> [ResponseTemplate] {
        templates(for: role).filter { $0.category == category }
    }

    // MARK: - All Templates (aggregated from role-specific files)

    static var allTemplates: [ResponseTemplate] {
        CommonTemplates.greetings +
        CommonTemplates.closings +
        Level1Templates.all +
        Level2Templates.all +
        FraudTemplates.all +
        ComplianceTemplates.all +
        TechSupportTemplates.all +
        TeamleadTemplates.all
    }

    // MARK: - Quick Snippets

    static func quickSnippet(_ key: String, for role: CSRRole) -> String? {
        QuickSnippets.snippets[key]?[role]
    }

    static var quickSnippetKeys: [String] {
        Array(QuickSnippets.snippets.keys)
    }
}
