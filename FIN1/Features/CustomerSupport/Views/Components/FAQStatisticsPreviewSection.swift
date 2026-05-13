import SwiftUI

// MARK: - FAQ Statistics Preview Section
/// Preview of FAQ statistics for CSR dashboard

struct FAQStatisticsPreviewSection: View {
    @ObservedObject var viewModel: FAQKnowledgeBaseViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text("Übersicht")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Button {
                    Task { await self.viewModel.loadStatistics() }
                } label: {
                    Text("Details")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }

            HStack(spacing: ResponsiveDesign.spacing(12)) {
                FAQStatisticCard(
                    icon: "doc.text.fill",
                    value: self.viewModel.formattedStatisticsTotalArticles,
                    label: "Artikel",
                    color: AppTheme.accentLightBlue
                )

                FAQStatisticCard(
                    icon: "checkmark.circle.fill",
                    value: self.viewModel.formattedStatisticsPublished,
                    label: "Veröffentlicht",
                    color: AppTheme.accentGreen
                )

                FAQStatisticCard(
                    icon: "hand.thumbsup.fill",
                    value: self.viewModel.formattedStatisticsHelpfulness,
                    label: "Hilfreich",
                    color: AppTheme.accentOrange
                )

                FAQStatisticCard(
                    icon: "eye.fill",
                    value: self.viewModel.formattedStatisticsViews,
                    label: "Aufrufe",
                    color: Color.purple
                )
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

