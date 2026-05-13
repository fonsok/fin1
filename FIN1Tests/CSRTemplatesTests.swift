@testable import FIN1
import XCTest

/// Tests for CSR Response Templates
final class CSRTemplatesTests: XCTestCase {

    // MARK: - Template Library Tests

    func testTemplatesLibrary_ReturnsTemplatesForAllRoles() {
        for role in CSRRole.allCases {
            let templates = CSRTemplatesLibrary.templates(for: role)
            XCTAssertGreaterThan(
                templates.count, 0,
                "Should have templates for \(role.displayName)"
            )
        }
    }

    func testTemplatesLibrary_FiltersByCategory() {
        let greetingTemplates = CSRTemplatesLibrary.templates(for: .level1, category: .greeting)

        XCTAssertGreaterThan(greetingTemplates.count, 0)
        for template in greetingTemplates {
            XCTAssertEqual(template.category, .greeting)
        }
    }

    func testTemplatesLibrary_AllTemplatesHaveRequiredFields() {
        let allTemplates = CSRTemplatesLibrary.allTemplates

        for template in allTemplates {
            XCTAssertFalse(template.id.isEmpty, "Template should have an ID")
            XCTAssertFalse(template.title.isEmpty, "Template should have a title")
            XCTAssertFalse(template.body.isEmpty, "Template should have a body")
            XCTAssertGreaterThan(
                template.availableForRoles.count, 0,
                "Template should be available to at least one role"
            )
        }
    }

    // MARK: - Common Templates Tests

    func testCommonTemplates_AvailableToAllRoles() {
        let greetings = CommonTemplates.greetings
        let closings = CommonTemplates.closings

        XCTAssertGreaterThan(greetings.count, 0, "Should have greeting templates")
        XCTAssertGreaterThan(closings.count, 0, "Should have closing templates")

        for template in greetings {
            XCTAssertEqual(
                template.availableForRoles.count,
                CSRRole.allCases.count,
                "Greetings should be available to all roles"
            )
        }
    }

    // MARK: - Role-Specific Templates Tests

    func testLevel1Templates_ExistAndAreCorrectlyAssigned() {
        let templates = Level1Templates.all

        for template in templates {
            XCTAssertTrue(
                template.availableForRoles.contains(.level1),
                "Level1 templates should be available to Level1 role"
            )
        }
    }

    func testFraudTemplates_HaveFraudCategory() {
        let templates = FraudTemplates.all
        let fraudCategoryTemplates = templates.filter { $0.category == .fraud }

        XCTAssertGreaterThan(
            fraudCategoryTemplates.count, 0,
            "Fraud templates should include fraud category templates"
        )
    }

    func testComplianceTemplates_IncludeGDPRTemplates() {
        let templates = ComplianceTemplates.all
        let gdprTemplates = templates.filter { $0.category == .gdpr }

        XCTAssertGreaterThanOrEqual(
            gdprTemplates.count, 2,
            "Compliance should have at least 2 GDPR templates (Art. 15 and Art. 17)"
        )
    }

    func testTeamleadTemplates_HaveEscalationTemplates() {
        let templates = TeamleadTemplates.all
        let escalationTemplates = templates.filter { $0.category == .escalation }

        XCTAssertGreaterThan(
            escalationTemplates.count, 0,
            "Teamlead should have escalation templates"
        )
    }

    // MARK: - Quick Snippets Tests

    func testQuickSnippets_AllKeysHaveSnippetsForAllRoles() {
        let keys = QuickSnippets.allKeys

        for key in keys {
            for role in CSRRole.allCases {
                let snippet = QuickSnippets.snippet(key, for: role)
                XCTAssertNotNil(
                    snippet,
                    "Key '\(key)' should have a snippet for \(role.displayName)"
                )
                XCTAssertFalse(
                    snippet?.isEmpty ?? true,
                    "Snippet for '\(key)' and \(role.displayName) should not be empty"
                )
            }
        }
    }

    func testQuickSnippets_SnippetsAreRoleSpecific() {
        // "Bitte warten" snippet should differ by role
        let level1Snippet = QuickSnippets.snippet("Bitte warten", for: .level1)
        let fraudSnippet = QuickSnippets.snippet("Bitte warten", for: .fraud)

        XCTAssertNotEqual(
            level1Snippet,
            fraudSnippet,
            "Snippets should be role-specific"
        )
    }

    // MARK: - Template Category Tests

    func testTemplateCategory_AllCategoriesHaveIcons() {
        for category in TemplateCategory.allCases {
            XCTAssertFalse(
                category.icon.isEmpty,
                "Category \(category) should have an icon"
            )
        }
    }

    // MARK: - Email Templates Tests

    func testEmailTemplates_HaveSubjectLines() {
        let allTemplates = CSRTemplatesLibrary.allTemplates
        let emailTemplates = allTemplates.filter { $0.isEmail }

        for template in emailTemplates {
            XCTAssertNotNil(
                template.subject,
                "Email template '\(template.title)' should have a subject"
            )
            XCTAssertFalse(
                template.subject?.isEmpty ?? true,
                "Email template subject should not be empty"
            )
        }
    }

    // MARK: - Placeholder Tests

    func testTemplates_PlaceholdersAreInBody() {
        let allTemplates = CSRTemplatesLibrary.allTemplates

        for template in allTemplates where !template.placeholders.isEmpty {
            for placeholder in template.placeholders {
                XCTAssertTrue(
                    template.body.contains(placeholder),
                    "Template '\(template.title)' should contain placeholder \(placeholder)"
                )
            }
        }
    }

    // MARK: - ResponseTemplate Codable Tests

    func testResponseTemplate_EncodesAndDecodes() throws {
        let template = ResponseTemplate(
            title: "Test",
            category: .greeting,
            body: "Test body",
            availableForRoles: [.level1]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(template)

        let decoder = JSONDecoder()
        let decodedTemplate = try decoder.decode(ResponseTemplate.self, from: data)

        XCTAssertEqual(template.title, decodedTemplate.title)
        XCTAssertEqual(template.category, decodedTemplate.category)
        XCTAssertEqual(template.body, decodedTemplate.body)
    }
}
