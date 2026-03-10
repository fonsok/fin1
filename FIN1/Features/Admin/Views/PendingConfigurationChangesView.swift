import SwiftUI

// MARK: - Pending Configuration Changes View
/// View for displaying and managing 4-eyes approval workflow for critical configuration changes.
/// Subviews in PendingConfiguration/ (ChangeDetails, ApprovalSheet, RejectionSheet, PendingChangeCard, PendingApprovalsNavigationLink).
struct PendingConfigurationChangesView: View {
    @Environment(\.appServices) private var appServices
    @StateObject private var viewModel: PendingConfigurationChangesViewModel

    init() {
        _viewModel = StateObject(wrappedValue: PendingConfigurationChangesViewModel())
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Pending Approvals")
                .navigationBarTitleDisplayMode(.large)
                .task {
                    viewModel.configure(with: appServices.configurationService)
                    await viewModel.loadPendingChanges()
                }
                .refreshable {
                    await viewModel.loadPendingChanges()
                }
                .sheet(isPresented: $viewModel.showApprovalSheet) {
                    PendingConfigurationApprovalSheet(viewModel: viewModel)
                }
                .sheet(isPresented: $viewModel.showRejectionSheet) {
                    PendingConfigurationRejectionSheet(viewModel: viewModel)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.pendingChanges.isEmpty {
            loadingView
        } else if viewModel.pendingChanges.isEmpty {
            emptyStateView
        } else {
            pendingChangesList
        }
    }

    private var loadingView: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading pending changes...")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: ResponsiveDesign.iconSize() * 3))
                .foregroundColor(.green)

            Text("No Pending Changes")
                .font(ResponsiveDesign.titleFont())
                .foregroundColor(.primary)

            Text("All configuration change requests have been processed.")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }

            Button {
                Task {
                    await viewModel.loadPendingChanges()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pendingChangesList: some View {
        ScrollView {
            LazyVStack(spacing: ResponsiveDesign.spacing(16)) {
                if let success = viewModel.successMessage {
                    successBanner(success)
                }

                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                headerSection

                ForEach(viewModel.pendingChanges) { change in
                    PendingChangeCard(change: change, viewModel: viewModel)
                }
            }
            .padding()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("4-Eyes Approval Required")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(.primary)
                Spacer()
                Text("\(viewModel.pendingCount)")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }

            Text("The following configuration changes require approval from a second administrator before they can be applied.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private func successBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(message)
                .font(ResponsiveDesign.bodyFont())
            Spacer()
            Button {
                viewModel.successMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(ResponsiveDesign.bodyFont())
            Spacer()
            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

// MARK: - Preview
#Preview {
    PendingConfigurationChangesView()
        .environment(\.appServices, AppServices.live)
}
