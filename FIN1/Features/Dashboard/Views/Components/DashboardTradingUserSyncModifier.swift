import SwiftUI

/// Keeps dashboard trading gates in sync with `UserService` after in-session registration completes.
struct DashboardTradingUserSyncModifier: ViewModifier {
    @Environment(\.appServices) private var appServices
    @Binding var syncedUser: User?

    func body(content: Content) -> some View {
        content
            .onAppear(perform: self.syncUser)
            .onReceive(NotificationCenter.default.publisher(for: .userDataDidUpdate)) { _ in
                self.syncUser()
            }
            .onReceive(NotificationCenter.default.publisher(for: .userDidSignIn)) { _ in
                self.syncUser()
            }
            .onReceive(NotificationCenter.default.publisher(for: .registrationDidFinalize)) { _ in
                self.syncUser()
            }
    }

    private func syncUser() {
        self.syncedUser = self.appServices.userService.currentUser
    }
}

extension View {
    func dashboardTradingUserSync(_ syncedUser: Binding<User?>) -> some View {
        modifier(DashboardTradingUserSyncModifier(syncedUser: syncedUser))
    }
}
