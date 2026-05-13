import Foundation
import SwiftUI

// MARK: - Simplified Dashboard View
/// Simplified main dashboard view that delegates to DashboardContainer
struct DashboardView: View {
    var body: some View {
        DashboardContainer()
    }
}

#Preview {
    DashboardView()
        .environmentObject(TabRouter())
}
