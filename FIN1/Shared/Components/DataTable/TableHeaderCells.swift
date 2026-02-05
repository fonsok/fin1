import SwiftUI

// MARK: - Table Header Cell
struct TableHeaderCell: View {
    let column: TableColumn
    let headerColor: Color
    let headerFontWeight: Font.Weight

    var body: some View {
        StaticHeaderCell(column: column, headerColor: headerColor, headerFontWeight: headerFontWeight)
            .frame(width: columnWidth, alignment: column.alignment)
    }

    private var columnWidth: CGFloat? {
        switch column.width {
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
            ForEach(Array(titleLines.indices), id: \.self) { index in
                HStack(spacing: ResponsiveDesign.spacing(2)) {
                    // Leading spacer for center alignment
                    if column.alignment == .center {
                        Spacer()
                    }

                    Text(titleLines[index])
                        .font(.caption)
                        .fontWeight(headerFontWeight)
                        .foregroundColor(headerColor)

                    // Add info icon after the last word of the last line (footnote-style)
                    if index == titleLines.count - 1 && column.infoText != nil {
                        Button(action: {
                            showInfo = true
                        }) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.accentLightBlue.opacity(0.8))
                        }
                        .padding(.leading, 2)
                    }

                    // Trailing spacer for center alignment
                    if column.alignment == .center {
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: column.alignment == .leading ? .leading : .center)
            }
        }
        .multilineTextAlignment(column.alignment == .leading ? .leading : .center)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: column.alignment)
        .sheet(isPresented: $showInfo) {
            InfoSheet(title: column.title, infoText: column.infoText ?? "")
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var titleLines: [String] {
        column.title.components(separatedBy: "\n")
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
                    Text(title.replacingOccurrences(of: "\n", with: " "))
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)

                    Text(infoText)
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
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }
}
