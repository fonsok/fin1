import SwiftUI

/// Sheet to close selected tickets with optional reason.
struct BulkCloseSheet: View {
    let selectedCount: Int
    let onClose: (String) -> Void

    @State private var reason = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(ResponsiveDesign.largeTitleFont())
                    .foregroundColor(AppTheme.accentOrange)

                Text("\(self.selectedCount) Tickets schließen?")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                Text("Diese Aktion kann nicht rückgängig gemacht werden.")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    Text("Begründung")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    TextEditor(text: self.$reason)
                        .frame(minHeight: 100)
                        .padding(ResponsiveDesign.spacing(12))
                        .background(AppTheme.sectionBackground)
                        .cornerRadius(ResponsiveDesign.spacing(10))
                        .scrollContentBackground(.hidden)
                }
                .padding()

                Spacer()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Tickets schließen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { self.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        self.onClose(self.reason.isEmpty ? "Massenbearbeitung" : self.reason)
                    }
                    .foregroundColor(AppTheme.accentRed)
                }
            }
        }
    }
}
