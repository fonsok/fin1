import SwiftUI

// MARK: - Table Header Cell
struct TableHeaderCell: View {
    let column: TableColumn
    let headerColor: Color
    let headerFontWeight: Font.Weight

    var body: some View {
        StaticHeaderCell(column: self.column, headerColor: self.headerColor, headerFontWeight: self.headerFontWeight)
            .frame(width: self.columnWidth, alignment: self.column.alignment)
    }

    private var columnWidth: CGFloat? {
        switch self.column.width {
        case .flexible:
            return nil
        case .fixed(let width):
            return width
        }
    }
}

// MARK: - Static Header Cell (VVaaa Style)
struct StaticHeaderCell: View {
    let column: TableColumn
    let headerColor: Color
    let headerFontWeight: Font.Weight
    @State private var showInfo = false

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(2)) {
            ForEach(Array(self.titleLines.indices), id: \.self) { index in
                HStack(spacing: ResponsiveDesign.spacing(2)) {
                    // Leading spacer for center alignment
                    if self.column.alignment == .center {
                        Spacer()
                    }

                    Text(self.titleLines[index])
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(self.headerFontWeight)
                        .foregroundColor(self.headerColor)

                    // Add info icon after the last word of the last line (footnote-style)
                    if index == self.titleLines.count - 1 && self.column.infoText != nil {
                        Button(action: {
                            self.showInfo = true
                        }) {
                            Image(systemName: "info.circle.fill")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.accentLightBlue.opacity(0.8))
                        }
                        .padding(.leading, ResponsiveDesign.spacing(2))
                    }

                    // Trailing spacer for center alignment
                    if self.column.alignment == .center {
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: self.column.alignment == .leading ? .leading : .center)
            }
        }
        .multilineTextAlignment(self.column.alignment == .leading ? .leading : .center)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: self.column.alignment)
        .sheet(isPresented: self.$showInfo) {
            InfoSheet(title: self.column.title, infoText: self.column.infoText ?? "")
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var titleLines: [String] {
        self.column.title.components(separatedBy: "\n")
    }
}

// MARK: - Info Sheet
struct InfoSheet: View {
    let title: String
    let infoText: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
                    Text(self.title.replacingOccurrences(of: "\n", with: " "))
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)

                    Text(self.infoText)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(ResponsiveDesign.horizontalPadding())
                .padding(.top, ResponsiveDesign.spacing(4))
                .padding(.bottom, ResponsiveDesign.spacing(16))
            }
            .background(AppTheme.screenBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        self.dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }
}
