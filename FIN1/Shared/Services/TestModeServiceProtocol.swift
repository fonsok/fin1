import Foundation
import SwiftUI
import Combine

// MARK: - Test Mode Service Protocol
/// Defines the contract for test mode operations and management
protocol TestModeServiceProtocol: ObservableObject {
    var isTestModeEnabled: Bool { get set }
    var testModeSettings: TestModeSettings { get set }
    var availableTestUsers: [TestUser] { get }
    var currentTestUser: TestUser? { get set }

    // MARK: - Test Mode Management
    func enableTestMode()
    func disableTestMode()
    func toggleTestMode()
    func resetTestMode()

    // MARK: - Test User Management
    func createTestUser(_ user: TestUser)
    func switchToTestUser(_ user: TestUser)
    func clearTestUsers()

    // MARK: - Test Mode Queries
    func isInTestMode() -> Bool
    func getTestModeStatus() -> String
    func getTestModeConfiguration() -> TestModeConfiguration
}

// MARK: - Test Mode Service Implementation
/// Handles test mode operations, settings, and test user management
final class TestModeService: TestModeServiceProtocol, ServiceLifecycle, @unchecked Sendable {
    static let shared = TestModeService()

    @Published var isTestModeEnabled: Bool = false
    @Published var testModeSettings: TestModeSettings = TestModeSettings()
    @Published var availableTestUsers: [TestUser] = []
    @Published var currentTestUser: TestUser?

    // MARK: - Sample Images for Test Mode
    @Published var sampleAddressDocument: UIImage?
    @Published var samplePassportImage: UIImage?
    @Published var sampleIDCardImage: UIImage?

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupDefaultTestUsers()
        setupSampleImages()
        loadTestModeSettings()
    }

    // MARK: - ServiceLifecycle

    func start() {
        print("🔄 TestModeService started")
    }

    func stop() {
        print("🛑 TestModeService stopped")
    }

    func reset() {
        resetTestMode()
        print("🔄 TestModeService reset")
    }

    // MARK: - Test Mode Management

    func enableTestMode() {
        isTestModeEnabled = true
        saveTestModeSettings()
    }

    func disableTestMode() {
        isTestModeEnabled = false
        currentTestUser = nil
        saveTestModeSettings()
    }

    func toggleTestMode() {
        isTestModeEnabled.toggle()
        if !isTestModeEnabled {
            currentTestUser = nil
        }
        saveTestModeSettings()
    }

    func resetTestMode() {
        isTestModeEnabled = false
        currentTestUser = nil
        testModeSettings = TestModeSettings()
        saveTestModeSettings()
    }

    // MARK: - Test User Management

    func createTestUser(_ user: TestUser) {
        if !availableTestUsers.contains(where: { $0.id == user.id }) {
            availableTestUsers.append(user)
        }
    }

    func switchToTestUser(_ user: TestUser) {
        currentTestUser = user
        saveTestModeSettings()
    }

    func clearTestUsers() {
        availableTestUsers.removeAll()
        currentTestUser = nil
        saveTestModeSettings()
    }

    // MARK: - Test Mode Queries

    func isInTestMode() -> Bool {
        return isTestModeEnabled
    }

    func getTestModeStatus() -> String {
        if isTestModeEnabled {
            if let currentUser = currentTestUser {
                return "Test Mode: \(currentUser.name) (\(currentUser.role.displayName))"
            } else {
                return "Test Mode: Enabled (No user selected)"
            }
        } else {
            return "Test Mode: Disabled"
        }
    }

    func getTestModeConfiguration() -> TestModeConfiguration {
        return TestModeConfiguration(
            isEnabled: isTestModeEnabled,
            settings: testModeSettings,
            currentUser: currentTestUser
        )
    }

    // MARK: - Private Methods

    private func setupDefaultTestUsers() {
        availableTestUsers = [
            TestUser(
                id: "test1",
                name: "Test Investor",
                email: "investor@test.com",
                password: "password",
                role: .investor,
                riskClass: .riskClass3
            ),
            TestUser(
                id: "test2",
                name: "Test Trader",
                email: "trader@test.com",
                password: "password",
                role: .trader,
                riskClass: .riskClass5
            ),
            TestUser(
                id: "test3",
                name: "Other User",
                email: "other@test.com",
                password: "password",
                role: .admin,
                riskClass: .riskClass1
            )
        ]
    }

    private func setupSampleImages() {
        // Create sample images for test mode
        // These would typically be loaded from the app bundle or created programmatically
        sampleAddressDocument = createSampleImage(named: "sample_address_document")
        samplePassportImage = createSampleImage(named: "sample_passport")
        sampleIDCardImage = createSampleImage(named: "sample_id_card")
    }

    private func createSampleImage(named: String) -> UIImage? {
        // Create a simple colored rectangle as a placeholder
        // In a real app, these would be actual sample images from the bundle
        let size = CGSize(width: 300, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Add some text to identify the image type
            let text = named.replacingOccurrences(of: "sample_", with: "").replacingOccurrences(of: "_", with: " ").capitalized
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 16, weight: .medium)
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
    }

    private func loadTestModeSettings() {
        // Load from UserDefaults or other persistent storage
        if let data = UserDefaults.standard.data(forKey: "TestModeSettings"),
           let settings = try? JSONDecoder().decode(TestModeSettings.self, from: data) {
            testModeSettings = settings
        }

        isTestModeEnabled = UserDefaults.standard.bool(forKey: "TestModeEnabled")

        if let userData = UserDefaults.standard.data(forKey: "CurrentTestUser"),
           let user = try? JSONDecoder().decode(TestUser.self, from: userData) {
            currentTestUser = user
        }
    }

    private func saveTestModeSettings() {
        // Save to UserDefaults or other persistent storage
        if let data = try? JSONEncoder().encode(testModeSettings) {
            UserDefaults.standard.set(data, forKey: "TestModeSettings")
        }

        UserDefaults.standard.set(isTestModeEnabled, forKey: "TestModeEnabled")

        if let user = currentTestUser,
           let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "CurrentTestUser")
        } else {
            UserDefaults.standard.removeObject(forKey: "CurrentTestUser")
        }
    }
}

// MARK: - Supporting Types

struct TestModeSettings: Codable {
    var enableMockData: Bool = true
    var enableNetworkSimulation: Bool = true
    var networkLatency: Double = 0.5
    var enableErrorSimulation: Bool = false
    var errorRate: Double = 0.1
}

struct TestUser: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let password: String
    let role: UserRole
    let riskClass: RiskClass
}

struct TestModeConfiguration {
    let isEnabled: Bool
    let settings: TestModeSettings
    let currentUser: TestUser?
}
