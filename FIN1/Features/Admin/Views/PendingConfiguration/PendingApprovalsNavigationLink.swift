import SwiftUI

/// Navigation link to pending approvals with optional count badge.
struct PendingApprovalsNavigationLink: View {
    @Environment(\.appServices) private var appServices
    @StateObject private var viewModel = PendingApprovalsViewModel()

    var body: some View {
        NavigationLink {
            PendingConfigurationChangesView()
        } label: {
            HStack {
                Label("Pending Approvals", systemImage: "checkmark.seal")
                Spacer()
                if viewModel.pendingCount > 0 {
                    Text("\(viewModel.pendingCount)")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, ResponsiveDesign.spacing(8))
                        .padding(.vertical, ResponsiveDesign.spacing(2))
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            }
        }
        .task {
            viewModel.configure(with: appServices.configurationService)
            await viewModel.loadPendingCount()
        }
    }
}
