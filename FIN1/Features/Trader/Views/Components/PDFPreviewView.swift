import SwiftUI

// MARK: - PDF Preview View
/// Displays a preview of the generated PDF
struct PDFPreviewView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(minWidth: UIScreen.main.bounds.width)
                    .padding(ResponsiveDesign.spacing(16))
            }
            .navigationTitle("PDF Vorschau")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    PDFPreviewView(image: UIImage(systemName: "doc.text") ?? UIImage())
}











