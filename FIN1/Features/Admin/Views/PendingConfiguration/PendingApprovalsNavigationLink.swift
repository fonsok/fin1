import SwiftUI

/// Navigation link to pending approvals with optional count badge.
struct PendingApprovalsNavigationLink: View {
    @Environment(\.appServices) private var appServices
    @State private var pendingCount = 0

    var body: some View {
        NavigationLink {
            PendingConfigurationChangesView()
        } label: {
            HStack {
                Label("Pending Approvals", systemImage: "checkmark.seal")
                Spacer()
                if pendingCount > 0 {
                    Text("\(pendingCount)")
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
            await loadPendingCount()
        }
    }

    private func loadPendingCount() async {
        guard let service = appServices.configurationService as? ConfigurationService else { return }
        do {
            let changes = try await service.getPendingConfigurationChanges()
            pendingCount = changes.count
        } catch {
            pendingCount = 0
        }
    }
}
