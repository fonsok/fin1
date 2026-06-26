import Combine
import SwiftUI

/// Mirrors `UserServiceProtocol` into `@Published` fields so SwiftUI re-renders on session changes.
@MainActor
final class UserSessionObserver: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var onboardingCompleted = false
    @Published private(set) var currentUser: User?

    private var userService: (any UserServiceProtocol)?
    private var cancellables = Set<AnyCancellable>()

    func bind(to userService: any UserServiceProtocol) {
        self.userService = userService
        self.sync()

        self.cancellables.removeAll()
        let names: [Notification.Name] = [
            .userDidSignIn,
            .userDidSignOut,
            .userDataDidUpdate,
            .registrationDidFinalize
        ]
        for name in names {
            NotificationCenter.default.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.sync()
                }
                .store(in: &self.cancellables)
        }
    }

    private func sync() {
        guard let userService else { return }
        self.isAuthenticated = userService.isAuthenticated
        self.currentUser = userService.currentUser
        self.onboardingCompleted = userService.currentUser?.onboardingCompleted == true
    }
}
