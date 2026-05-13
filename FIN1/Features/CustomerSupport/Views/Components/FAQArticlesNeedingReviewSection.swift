import SwiftUI

// MARK: - FAQ Articles Needing Review Section
/// Displays articles that need review (low helpfulness, outdated)

struct FAQArticlesNeedingReviewSection: View {
    @ObservedObject var viewModel: FAQKnowledgeBaseViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppTheme.accentRed)

                Text("Überprüfung erforderlich")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Text("\(self.viewModel.articlesNeedingReview.count)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.white)
                    .padding(.horizontal, ResponsiveDesign.spacing(8))
                    .padding(.vertical, ResponsiveDesign.spacing(4))
                    .background(AppTheme.accentRed)
                    .cornerRadius(ResponsiveDesign.spacing(8))
            }

            ForEach(self.viewModel.articlesNeedingReview.prefix(3)) { article in
                FAQArticleRow(article: article, isCSRMode: true, showReviewBadge: true) {
                    self.viewModel.selectArticle(article)
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

