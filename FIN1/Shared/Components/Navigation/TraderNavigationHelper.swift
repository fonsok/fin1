import SwiftUI

// MARK: - Trader ID Item
/// Identifiable wrapper for trader ID to use with `.sheet(item:)` pattern
struct TraderIDItem: Identifiable, Hashable {
    let id: String
}

// MARK: - Trader Navigation Helper
/// Centralized navigation logic for trader detail presentation to eliminate DRY violations
@MainActor
struct TraderNavigationHelper {

    // MARK: - Sheet Presentation
    /// Creates a sheet view for trader detail presentation
    /// - Parameters:
    ///   - traderID: The trader ID to display details for
    ///   - appServices: App services for dependency injection
    /// - Returns: A view wrapped in NavigationStack for sheet presentation
    @ViewBuilder
    static func sheetView(for traderID: String, appServices: AppServices) -> some View {
        if let trader = appServices.traderDataService.getTrader(by: traderID) {
            NavigationStack {
                TraderDetailsView(trader: trader)
            }
        } else {
            TraderNotFoundView(traderID: traderID)
        }
    }

    // MARK: - Navigation Destination
    /// Creates a navigation destination view for trader detail presentation
    /// - Parameters:
    ///   - traderID: The trader ID to display details for
    ///   - appServices: App services for dependency injection
    /// - Returns: A view for navigation destination
    @ViewBuilder
    static func navigationDestination(for traderID: String, appServices: AppServices) -> some View {
        if let trader = appServices.traderDataService.getTrader(by: traderID) {
            TraderDetailsView(trader: trader)
        } else {
            TraderNotFoundView(traderID: traderID)
        }
    }
}

// MARK: - Trader Not Found View
/// Error view displayed when a trader cannot be found
struct TraderNotFoundView: View {
    let traderID: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Text("Trader Not Found")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            Text("Unable to load trader details for: \(self.traderID)")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)

            Button("Close") {
                self.dismiss()
            }
            .responsivePadding()
            .background(AppTheme.accentLightBlue)
            .foregroundColor(AppTheme.fontColor)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
        .responsivePadding()
        .background(AppTheme.screenBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") {
                    self.dismiss()
                }
                .foregroundColor(AppTheme.accentLightBlue)
            }
        }
    }
}
