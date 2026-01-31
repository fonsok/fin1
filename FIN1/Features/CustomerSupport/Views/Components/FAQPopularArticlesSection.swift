import SwiftUI

// MARK: - FAQ Popular Articles Section
/// Displays popular/trending FAQ articles

struct FAQPopularArticlesSection: View {
    @ObservedObject var viewModel: FAQKnowledgeBaseViewModel
    let isCSRMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(AppTheme.accentOrange)

                Text("Beliebte Artikel")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
            }

            if viewModel.popularArticles.isEmpty {
                Text("Noch keine beliebten Artikel")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .padding()
            } else {
                ForEach(viewModel.popularArticles) { article in
                    FAQArticleRow(article: article, isCSRMode: isCSRMode) {
                        viewModel.selectArticle(article)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

