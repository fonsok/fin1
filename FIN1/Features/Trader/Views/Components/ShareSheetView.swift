import SwiftUI

// MARK: - Share Sheet View
/// SwiftUI-native share sheet using ShareLink
/// Replaces UIActivityViewController
struct ShareSheetView: View {
    let pdfURL: URL
    let invoiceNumber: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(6)) {
                Text("PDF Teilen")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .padding()

                ShareLink(
                    item: pdfURL,
                    subject: Text("Rechnung \(invoiceNumber)"),
                    message: Text("Anbei finden Sie die Rechnung \(invoiceNumber).")
                ) {
                    Label("PDF Teilen", systemImage: "square.and.arrow.up")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.accentLightBlue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.sectionBackground)
                        .cornerRadius(ResponsiveDesign.spacing(12))
                }
                .padding()

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }
}
