import SwiftUI

/// List of approval requests with empty state for 4-eyes queue.
struct FourEyesApprovalQueueRequestsSection: View {
    @ObservedObject var viewModel: FourEyesApprovalQueueViewModel
    var onSelectRequest: (FourEyesApprovalRequest) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text("Ausstehende Anfragen")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if viewModel.filteredRequests.isEmpty {
                emptyStateView
            } else {
                ForEach(viewModel.filteredRequests) { request in
                    ApprovalRequestCard(request: request) {
                        onSelectRequest(request)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var emptyStateView: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: ResponsiveDesign.iconSize() * 2))
                .foregroundColor(AppTheme.accentGreen.opacity(0.5))

            Text("Keine ausstehenden Genehmigungen")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Text("Alle 4-Augen-Anfragen wurden bearbeitet")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ResponsiveDesign.spacing(32))
    }
}
