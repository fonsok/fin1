import SwiftUI

// MARK: - FAQ Categories Section
/// Category filtering and article display

struct FAQCategoriesSection: View {
    @ObservedObject var viewModel: FAQKnowledgeBaseViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Kategorien")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    FAQCategoryChip(
                        title: "Alle",
                        icon: "square.grid.2x2.fill",
                        isSelected: self.viewModel.selectedCategory == nil
                    ) {
                        self.viewModel.selectCategory(nil)
                    }

                    ForEach(self.viewModel.categories) { category in
                        FAQCategoryChip(
                            title: category.displayName,
                            icon: category.icon,
                            isSelected: self.viewModel.selectedCategory == category
                        ) {
                            self.viewModel.selectCategory(category)
                        }
                    }
                }
            }

            // Articles in selected category
            if self.viewModel.selectedCategory != nil {
                let categoryArticles = self.viewModel.filteredArticles
                if categoryArticles.isEmpty {
                    Text("Keine Artikel in dieser Kategorie")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .padding()
                } else {
                    ForEach(categoryArticles.prefix(5)) { article in
                        FAQArticleRow(article: article, isCSRMode: true) {
                            self.viewModel.selectArticle(article)
                        }
                    }

                    if categoryArticles.count > 5 {
                        Text("+ \(categoryArticles.count - 5) weitere Artikel")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.accentLightBlue)
                            .padding(.top, ResponsiveDesign.spacing(4))
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

