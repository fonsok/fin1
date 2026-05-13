import SwiftUI

/// Documents list section for customer detail.
struct CustomerDetailDocumentsSection: View {
    let documents: [CustomerDocumentSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(AppTheme.accentOrange)

                Text("Dokumente")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                if !self.documents.isEmpty {
                    Text("\(self.documents.count)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .padding(.horizontal, ResponsiveDesign.spacing(8))
                        .padding(.vertical, ResponsiveDesign.spacing(4))
                        .background(AppTheme.accentOrange.opacity(0.1))
                        .cornerRadius(ResponsiveDesign.spacing(6))
                }
            }

            if self.documents.isEmpty {
                Text("Keine Dokumente vorhanden")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .padding()
            } else {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    ForEach(self.documents) { document in
                        DocumentRow(document: document)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}
