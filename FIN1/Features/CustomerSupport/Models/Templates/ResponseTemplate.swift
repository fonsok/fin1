import Foundation

// MARK: - Response Template
/// A reusable response template for CSR communications
struct ResponseTemplate: Identifiable, Codable {
    let id: String
    let title: String
    let category: TemplateCategory
    let subject: String?  // For email templates
    let body: String
    let availableForRoles: [CSRRole]
    let placeholders: [String]  // e.g., ["{{KUNDENNAME}}", "{{TICKETNUMMER}}"]
    let isEmail: Bool  // true = Email template, false = Chat snippet

    init(
        id: String = UUID().uuidString,
        title: String,
        category: TemplateCategory,
        subject: String? = nil,
        body: String,
        availableForRoles: [CSRRole],
        placeholders: [String] = [],
        isEmail: Bool = false
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.subject = subject
        self.body = body
        self.availableForRoles = availableForRoles
        self.placeholders = placeholders
        self.isEmail = isEmail
    }
}
