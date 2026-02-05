import SwiftUI

// MARK: - FAQ Statistics Sheet
/// Sheet displaying FAQ statistics and analytics

struct FAQStatisticsSheet: View {
    @ObservedObject var viewModel: FAQKnowledgeBaseViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    if let stats = viewModel.statistics {
                        overviewSection(stats)
                        categoriesSection(stats)
                        topArticlesSection(stats)
                    } else {
                        ProgressView()
                            .padding()
                    }
                }
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                .padding(.top, ResponsiveDesign.spacing(8))
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("FAQ Statistiken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func overviewSection(_ stats: FAQStatistics) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Übersicht")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: ResponsiveDesign.spacing(12)) {
                FAQStatBox(title: "Gesamt", value: "\(stats.totalArticles)", icon: "doc.text.fill", color: AppTheme.accentLightBlue)
                FAQStatBox(title: "Veröffentlicht", value: "\(stats.publishedArticles)", icon: "checkmark.circle.fill", color: AppTheme.accentGreen)
                FAQStatBox(title: "Archiviert", value: "\(stats.archivedArticles)", icon: "archivebox.fill", color: AppTheme.fontColor.opacity(0.6))
                FAQStatBox(title: "Überprüfen", value: "\(stats.articlesNeedingReview)", icon: "exclamationmark.triangle.fill", color: AppTheme.accentRed)
            }

            Divider()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: ResponsiveDesign.spacing(12)) {
                FAQStatBox(title: "Aufrufe", value: "\(stats.totalViews)", icon: "eye.fill", color: Color.purple)
                FAQStatBox(title: "Hilfreich", value: "\(stats.overallHelpfulnessPercentage)%", icon: "hand.thumbsup.fill", color: AppTheme.accentOrange)
                FAQStatBox(title: "Positiv", value: "\(stats.totalHelpfulVotes)", icon: "plus.circle.fill", color: AppTheme.accentGreen)
                FAQStatBox(title: "Negativ", value: "\(stats.totalNotHelpfulVotes)", icon: "minus.circle.fill", color: AppTheme.accentRed)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private func categoriesSection(_ stats: FAQStatistics) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Nach Kategorie")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            ForEach(KnowledgeBaseCategory.allCases) { category in
                let count = stats.articlesByCategory[category.rawValue] ?? 0
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(Color(hex: category.color))
                        .frame(width: ResponsiveDesign.spacing(24))

                    Text(category.displayName)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)

                    Spacer()

                    Text("\(count)")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor)
                }
                .padding(.vertical, ResponsiveDesign.spacing(4))
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private func topArticlesSection(_ stats: FAQStatistics) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Top Artikel")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            if stats.topViewedArticles.isEmpty {
                Text("Noch keine Daten verfügbar")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            } else {
                ForEach(viewModel.popularArticles) { article in
                    HStack {
                        Text(article.title)
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor)
                            .lineLimit(1)

                        Spacer()

                        Text("\(article.viewCount)")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))

                        Image(systemName: "eye")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    }
                    .padding(.vertical, ResponsiveDesign.spacing(4))
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - FAQ Stat Box

struct FAQStatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: icon)
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(color)

            Text(value)
                .font(ResponsiveDesign.titleFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.inputText)

            Text(title)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.inputText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.inputFieldBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

