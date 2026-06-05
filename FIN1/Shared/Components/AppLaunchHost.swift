import SwiftUI

/// Shows UI immediately, then bootstraps `AppServices.live` off the critical first frame.
@MainActor
struct AppLaunchHost: View {
    @StateObject private var launchModel = AppLaunchModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let context = self.launchModel.context {
                AppRootContent(
                    services: context.services,
                    lifecycleCoordinator: context.lifecycleCoordinator,
                    launchStartTime: self.launchModel.launchStartTime
                )
            } else {
                ZStack {
                    AppTheme.screenBackground
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(AppTheme.accentLightBlue)
                }
                .accessibilityIdentifier("AppLaunchPlaceholder")
            }
        }
        .task {
            await self.launchModel.bootstrapIfNeeded()
        }
    }
}

@MainActor
final class AppLaunchModel: ObservableObject {
    struct LaunchContext {
        let services: AppServices
        let lifecycleCoordinator: ServiceLifecycleCoordinator
    }

    let launchStartTime = Date()
    @Published private(set) var context: LaunchContext?

    func bootstrapIfNeeded() async {
        guard self.context == nil else { return }

        let started = CFAbsoluteTimeGetCurrent()
        let services = AppServices.live
        let coordinator = ServiceLifecycleCoordinator(services: services)
        self.context = LaunchContext(services: services, lifecycleCoordinator: coordinator)

        let elapsed = CFAbsoluteTimeGetCurrent() - started
        print("⚡ AppServices bootstrap: \(String(format: "%.3f", elapsed))s")
    }
}
