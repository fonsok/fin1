import SwiftUI

extension LeveragedProductsLearningView {
    // MARK: - Header & navigation

    var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(16))
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.accentLightBlue.opacity(0.38),
                            AppTheme.accentLightBlue.opacity(0.1),
                            AppTheme.sectionBackground.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(10)) {
                Label("Optionsscheine verstehen", systemImage: "graduationcap.fill")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.accentLightBlue)

                Text("Call/Put-Optionsscheine einfach erklärt")
                    .font(ResponsiveDesign.titleFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)

                Text("Grundlagen, Funktionsweise, Kennzahlen, Praxisbeispiele, Chancen und Risiken")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.78))
            }
            .padding(ResponsiveDesign.spacing(20))
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
    }

    func topicStrip(proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ResponsiveDesign.spacing(8)) {
                ForEach(LearningAnchor.chipAnchors) { anchor in
                    self.topicChip(anchor: anchor, proxy: proxy)
                }
            }
            .padding(.vertical, ResponsiveDesign.spacing(4))
        }
    }

    func topicChip(anchor: LearningAnchor, proxy: ScrollViewProxy) -> some View {
        let isSelected = self.highlightedAnchor == anchor

        return Button {
            self.highlightedAnchor = anchor
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(anchor.id, anchor: .top)
            }
        } label: {
            HStack(spacing: ResponsiveDesign.spacing(6)) {
                Image(systemName: anchor.icon)
                    .font(ResponsiveDesign.captionFont())
                Text(anchor.chipTitle)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
            }
            .foregroundColor(anchor.accentColor)
            .padding(.horizontal, ResponsiveDesign.spacing(12))
            .padding(.vertical, ResponsiveDesign.spacing(8))
            .background(anchor.accentColor.opacity(isSelected ? 0.28 : 0.12))
            .overlay(
                Capsule()
                    .stroke(anchor.accentColor.opacity(isSelected ? 0.65 : 0), lineWidth: 1.5)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
