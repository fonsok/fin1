import SwiftUI

/// Sheet for rejecting a pending configuration change.
struct PendingConfigurationRejectionSheet: View {
    @ObservedObject var viewModel: PendingConfigurationChangesViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(24)) {
                Image(systemName: "xmark.seal")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                    .foregroundColor(.red)

                Text("Reject Configuration Change")
                    .font(ResponsiveDesign.titleFont())

                if let changeId = viewModel.selectedChangeId,
                   let change = viewModel.pendingChanges.first(where: { $0.id == changeId }) {
                    PendingConfigurationChangeDetailsView(change: change, viewModel: viewModel)
                }

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    Text("Rejection Reason (required)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)

                    TextField("Provide reason for rejection...", text: $viewModel.rejectionReason, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }

                if viewModel.rejectionReason.isEmpty {
                    Text("A reason is required to reject this change")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.orange)
                }

                Spacer()

                HStack(spacing: ResponsiveDesign.spacing(16)) {
                    Button("Cancel") {
                        viewModel.dismissSheets()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task {
                            await viewModel.rejectSelectedChange()
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Reject")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(viewModel.isLoading || viewModel.rejectionReason.isEmpty)
                }
            }
            .padding()
            .navigationTitle("Reject Change")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.dismissSheets()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
