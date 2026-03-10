import Foundation

// MARK: - App Services Builder
/// Builds the complete service graph for the application.
/// Handles all dependency injection and service wiring.
/// Implementation is split into extensions: +BuildContext, +Core, +Trader, +Investment, +Remaining.
enum AppServicesBuilder {

    /// Builds all live services with proper dependency injection.
    static func buildLiveServices() -> AppServices {
        var ctx = AppServicesBuildContext()
        Core.build(&ctx)
        Trader.build(&ctx)
        Investment.build(&ctx)
        Remaining.build(&ctx)
        return ctx.toAppServices()
    }
}
