import SwiftUI

// MARK: - Status Update View
/// Modal view for updating invoice status
struct StatusUpdateView: View {
    let currentStatus: InvoiceStatus
    let onStatusSelected: (InvoiceStatus) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(InvoiceStatus.allCases, id: \.self) { status in
                    Button(action: {
                        onStatusSelected(status)
                    }, label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(status.displayName)
                                    .font(ResponsiveDesign.bodyFont())
                                    .foregroundColor(.primary)

                                if status == currentStatus {
                                    Text("Aktueller Status")
                                        .font(ResponsiveDesign.captionFont())
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            if status == currentStatus {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    })
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Status ändern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    StatusUpdateView(
        currentStatus: .draft,
        onStatusSelected: { _ in }
    )
}











