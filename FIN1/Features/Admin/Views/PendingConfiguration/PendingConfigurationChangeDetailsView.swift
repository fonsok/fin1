import SwiftUI

/// Reusable block showing current vs new value and reason for a pending configuration change.
struct PendingConfigurationChangeDetailsView: View {
    let change: PendingConfigurationChange
    @ObservedObject var viewModel: PendingConfigurationChangesViewModel

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text(self.viewModel.formatParameterName(self.change.parameterName))
                    .font(ResponsiveDesign.headlineFont())
                Spacer()
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Current Value")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)
                    Text(self.viewModel.formatValue(self.change.oldValue, for: self.change.parameterName))
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.primary)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)

                Spacer()

                VStack(alignment: .trailing) {
                    Text("New Value")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)
                    Text(self.viewModel.formatValue(self.change.newValue, for: self.change.parameterName))
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text("Reason: \(self.change.reason)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.secondary)
                Text("Requested by: \(self.change.requesterEmail ?? self.change.requesterId)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}
