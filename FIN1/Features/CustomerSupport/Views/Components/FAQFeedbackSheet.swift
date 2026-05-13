import SwiftUI

// MARK: - FAQ Feedback Sheet
/// Sheet for collecting user feedback on FAQ articles

struct FAQFeedbackSheet: View {
    let article: FAQArticle
    @ObservedObject var viewModel: FAQKnowledgeBaseViewModel
    let userId: String?

    @Environment(\.dismiss) private var dismiss
    @State private var comment = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Text("Was können wir verbessern?")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                TextEditor(text: self.$comment)
                    .font(ResponsiveDesign.bodyFont())
                    .frame(minHeight: ResponsiveDesign.spacing(120))
                    .padding(ResponsiveDesign.spacing(8))
                    .background(AppTheme.inputFieldBackground)
                    .cornerRadius(ResponsiveDesign.spacing(8))

                Button {
                    Task {
                        await self.viewModel.submitFeedback(
                            forArticle: self.article,
                            isHelpful: false,
                            comment: self.comment.isEmpty ? nil : self.comment,
                            userId: self.userId
                        )
                        self.dismiss()
                    }
                } label: {
                    Text("Feedback senden")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.accentLightBlue)
                        .cornerRadius(ResponsiveDesign.spacing(10))
                }

                Spacer()
            }
            .padding()
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        self.dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

