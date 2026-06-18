import SwiftUI

// MARK: - Shared investments table layout (Reserved, Active, Completed)

@MainActor
enum InvestmentsTableStyle {
    static var cellHorizontalPadding: CGFloat { ResponsiveDesign.spacing(12) }
    static var cellVerticalPadding: CGFloat { ResponsiveDesign.spacing(6) }
    static var headerMinHeight: CGFloat { 44 }
    static var tableShellBackground: Color { AppTheme.sectionBackground }
    static var headerBandBackground: Color { AppTheme.screenBackground.opacity(0.35) }

    static func dataRowBackground(isEven: Bool) -> Color {
        isEven ? AppTheme.screenBackground.opacity(0.3) : AppTheme.screenBackground.opacity(0.1)
    }
}

struct InvestmentsTableDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.systemSeparator)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Dark-blue table shell used under each trader group (Reserved/Active) or completed block.
    func investmentsTableShell() -> some View {
        self
            .background(InvestmentsTableStyle.tableShellBackground)
            .padding(.horizontal, ResponsiveDesign.mainHorizontalPadding())
            .padding(.vertical, ResponsiveDesign.spacing(4))
    }

    /// Header band styling shared across open and completed investment tables.
    func investmentsTableHeaderBand() -> some View {
        self
            .frame(minHeight: InvestmentsTableStyle.headerMinHeight)
            .padding(.horizontal, InvestmentsTableStyle.cellHorizontalPadding)
            .padding(.vertical, InvestmentsTableStyle.cellVerticalPadding)
            .background(InvestmentsTableStyle.headerBandBackground)
    }
}

struct InvestmentsTraderGroupHeader: View {
    let username: String
    let investmentCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
            HStack(spacing: ResponsiveDesign.spacing(4)) {
                Text("Trader:")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                Text("\"\(self.username)\"")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DataTableColors.traderNameColor)
            }

            Text("\(self.investmentCount) investment\(self.investmentCount == 1 ? "" : "s")")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.secondaryText)
        }
    }
}
