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
                AppLaunchPlaceholderView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.stripedCanvasBackground.ignoresSafeArea())
        .task {
            await self.launchModel.bootstrapIfNeeded()
        }
        .onAppear {
            Task { await self.launchModel.bootstrapIfNeeded() }
        }
    }
}

private struct AppLaunchPlaceholderView: View {
    var body: some View {
        ZStack {
            AppTheme.stripedCanvasBackground
                .ignoresSafeArea()
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                ProgressView()
                    .tint(AppTheme.accentLightBlue)
                    .scaleEffect(1.2)
                Text(AppBrand.appName)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
            }
        }
        .accessibilityIdentifier("AppLaunchPlaceholder")
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

        // Allow the launch placeholder to paint before the synchronous service graph build.
        await Task.yield()

        let started = CFAbsoluteTimeGetCurrent()
        let services = AppServices.live
        let coordinator = ServiceLifecycleCoordinator(services: services)
        self.context = LaunchContext(services: services, lifecycleCoordinator: coordinator)

        let elapsed = CFAbsoluteTimeGetCurrent() - started
        print("⚡ AppServices bootstrap: \(String(format: "%.3f", elapsed))s")
    }
}
