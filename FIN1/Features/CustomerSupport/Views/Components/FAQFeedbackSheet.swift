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

                TextEditor(text: $comment)
                    .font(ResponsiveDesign.bodyFont())
                    .frame(minHeight: ResponsiveDesign.spacing(120))
                    .padding(ResponsiveDesign.spacing(8))
                    .background(AppTheme.inputFieldBackground)
                    .cornerRadius(ResponsiveDesign.spacing(8))

                Button {
                    Task {
                        await viewModel.submitFeedback(
                            forArticle: article,
                            isHelpful: false,
                            comment: comment.isEmpty ? nil : comment,
                            userId: userId
                        )
                        dismiss()
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
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

