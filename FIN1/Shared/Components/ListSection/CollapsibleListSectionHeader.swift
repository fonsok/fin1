import SwiftUI

struct CollapsibleListSectionHeader: View {
    let title: String
    let itemCount: Int
    @Binding var isExpanded: Bool
    var trailingSummary: String?

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isExpanded.toggle()
            }
        }, label: {
            HStack(alignment: .firstTextBaseline, spacing: ResponsiveDesign.spacing(8)) {
                Text(self.title)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                if self.itemCount > 0 {
                    Text("(\(self.itemCount))")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.secondaryText)
                }

                Spacer()

                if let trailingSummary {
                    Text(trailingSummary)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.secondaryText)
                }

                Image(systemName: self.isExpanded ? "chevron.up" : "chevron.down")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        })
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(self.title), \(self.itemCount) Einträge")
        .accessibilityHint(self.isExpanded ? "Bereich einklappen" : "Bereich ausklappen")
    }
}

struct ListSectionFilterMenu: View {
    let label: String
    let value: String
    let options: [(id: String, title: String)]
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(4)) {
            Text("\(self.label):")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)

            Menu {
                ForEach(self.options, id: \.id) { option in
                    Button(option.title) {
                        self.onSelect(option.id)
                    }
                }
            } label: {
                HStack(spacing: ResponsiveDesign.spacing(4)) {
                    Text(self.value)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.accentOrange)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentOrange)
                }
            }
        }
    }
}
