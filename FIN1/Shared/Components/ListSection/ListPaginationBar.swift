import SwiftUI

/// Footer paging control — mirrors admin portal `PaginationBar`.
struct ListPaginationBar: View {
    let page: Int
    let pageSize: Int
    let total: Int
    let itemLabel: String
    let onPageChange: (Int) -> Void

    private var totalPages: Int {
        ClientSideListPagination.totalPages(total: self.total, pageSize: self.pageSize)
    }

    private var safePage: Int {
        min(max(0, self.page), self.totalPages - 1)
    }

    private var range: (from: Int, to: Int) {
        ClientSideListPagination.displayRange(page: self.safePage, pageSize: self.pageSize, total: self.total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(10)) {
            Text("Zeige \(self.range.from) bis \(self.range.to) von \(self.total) \(self.itemLabel)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.secondaryText)

            HStack(spacing: ResponsiveDesign.spacing(8)) {
                self.pageButton(title: "|<<", enabled: self.safePage > 0) {
                    self.onPageChange(0)
                }

                self.pageButton(title: "Zurück", enabled: self.safePage > 0) {
                    self.onPageChange(max(0, self.safePage - 1))
                }

                Text("Seite \(self.safePage + 1) / \(self.totalPages)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(minWidth: ResponsiveDesign.spacing(72))

                self.pageButton(title: "Weiter >>", enabled: self.safePage + 1 < self.totalPages) {
                    self.onPageChange(min(self.totalPages - 1, self.safePage + 1))
                }

                self.pageButton(title: ">>|", enabled: self.safePage + 1 < self.totalPages) {
                    self.onPageChange(self.totalPages - 1)
                }
            }
        }
        .padding(.horizontal, ResponsiveDesign.mainHorizontalPadding())
        .padding(.vertical, ResponsiveDesign.spacing(12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.systemSeparator)
                .frame(height: 1)
        }
    }

    private func pageButton(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.medium)
                .foregroundColor(enabled ? AppTheme.accentLightBlue : AppTheme.tertiaryText)
                .padding(.horizontal, ResponsiveDesign.spacing(8))
                .padding(.vertical, ResponsiveDesign.spacing(6))
                .background(AppTheme.inputFieldBackground.opacity(enabled ? 1 : 0.4))
                .cornerRadius(ResponsiveDesign.spacing(6))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
