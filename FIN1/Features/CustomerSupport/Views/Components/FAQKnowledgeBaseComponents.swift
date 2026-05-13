import SwiftUI

// MARK: - FAQ Knowledge Base Supporting Components
/// Reusable components for FAQ views

struct FAQStatisticCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(4)) {
            Image(systemName: self.icon)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(self.color)

            Text(self.value)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.inputText)

            Text(self.label)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.inputText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ResponsiveDesign.spacing(8))
        .background(AppTheme.inputFieldBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

struct FAQCategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: ResponsiveDesign.spacing(4)) {
                Image(systemName: self.icon)
                    .font(ResponsiveDesign.captionFont())

                Text(self.title)
                    .font(ResponsiveDesign.captionFont())
            }
            .padding(.horizontal, ResponsiveDesign.spacing(12))
            .padding(.vertical, ResponsiveDesign.spacing(8))
            .background(self.isSelected ? AppTheme.accentLightBlue : AppTheme.inputFieldBackground)
            .foregroundColor(self.isSelected ? .white : AppTheme.inputText)
            .cornerRadius(ResponsiveDesign.spacing(16))
        }
    }
}

struct FAQArticleRow: View {
    let article: FAQArticle
    let isCSRMode: Bool
    var showReviewBadge: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack(alignment: .top, spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: self.article.category.icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(Color(hex: self.article.category.color))
                    .frame(width: ResponsiveDesign.spacing(32))

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    HStack {
                        Text(self.article.title)
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.inputText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        if !self.article.isPublished {
                            Text("Entwurf")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(.white)
                                .padding(.horizontal, ResponsiveDesign.spacing(6))
                                .padding(.vertical, ResponsiveDesign.spacing(2))
                                .background(AppTheme.accentOrange)
                                .cornerRadius(ResponsiveDesign.spacing(4))
                        }

                        if self.showReviewBadge {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(AppTheme.accentRed)
                        }
                    }

                    Text(self.article.summary)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.inputText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: ResponsiveDesign.spacing(12)) {
                        Label("\(self.article.viewCount)", systemImage: "eye")
                        Label("\(self.article.helpfulnessPercentage)%", systemImage: "hand.thumbsup")

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(AppTheme.fontColor.opacity(0.3))
                    }
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.inputText)
                }
            }
            .padding()
            .background(AppTheme.inputFieldBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct FAQSearchResultRow: View {
    let result: FAQSearchResult
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack(alignment: .top, spacing: ResponsiveDesign.spacing(12)) {
                VStack {
                    Image(systemName: self.result.article.category.icon)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(Color(hex: self.result.article.category.color))

                    Text(String(format: "%.0f%%", self.result.matchScore * 20))
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentGreen)
                }
                .frame(width: ResponsiveDesign.spacing(40))

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text(self.result.article.title)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.inputText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(self.result.article.summary)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.inputText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if !self.result.matchedTerms.isEmpty {
                        HStack {
                            Text("Treffer:")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.5))

                            Text(self.result.matchedTerms.joined(separator: ", "))
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.accentLightBlue)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(AppTheme.fontColor.opacity(0.3))
            }
            .padding()
            .background(AppTheme.inputFieldBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
    }
}

