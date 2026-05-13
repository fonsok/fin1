import Combine
import SwiftUI

/// ViewModel for ModularProfileView
/// Handles notification count observation and user state management
@MainActor
final class ModularProfileViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var combinedUnreadCount: Int = 0
    @Published var totalNotificationsCount: Int = 0

    // MARK: - Dependencies

    private let notificationService: any NotificationServiceProtocol
    private let userService: any UserServiceProtocol
    private let documentService: any DocumentServiceProtocol

    // MARK: - Combine

    private nonisolated(unsafe) var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var currentUserId: String? {
        self.userService.currentUser?.id
    }

    // MARK: - Initialization

    init(
        notificationService: any NotificationServiceProtocol,
        userService: any UserServiceProtocol,
        documentService: any DocumentServiceProtocol
    ) {
        self.notificationService = notificationService
        self.userService = userService
        self.documentService = documentService

        self.setupObservations()
        self.updateCounts()
    }

    deinit {
        cancellables.removeAll()
        print("🧹 ModularProfileViewModel deallocated")
    }

    // MARK: - Setup

    private func setupObservations() {
        // Observe notification service changes
        // Cast to concrete type to access @Published publisher
        if let concreteNotificationService = notificationService as? NotificationService {
            // Observe notifications array changes
            concreteNotificationService.$notifications
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.updateCounts()
                }
                .store(in: &self.cancellables)

            // Observe combinedUnreadCount changes
            concreteNotificationService.$combinedUnreadCount
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.updateCounts()
                }
                .store(in: &self.cancellables)
        }

        // Observe document service changes
        if let concreteDocumentService = documentService as? DocumentService {
            concreteDocumentService.$documents
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.updateCounts()
                }
                .store(in: &self.cancellables)
        }

        // Observe user changes to update counts when user switches
        NotificationCenter.default.publisher(for: .userDidSignIn)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCounts()
            }
            .store(in: &self.cancellables)

        NotificationCenter.default.publisher(for: .userDataDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCounts()
            }
            .store(in: &self.cancellables)
    }

    // MARK: - Update Methods

    func updateCounts() {
        let userId = self.currentUserId
        self.combinedUnreadCount = self.notificationService.getCombinedUnreadCount(for: userId)
        self.totalNotificationsCount = self.notificationService.notifications.count
    }
}
