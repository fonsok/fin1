import SwiftUI

// MARK: - Year Separator Row
/// Displays a year separator row in the performance table
struct YearSeparatorRow: View {
    let year: Int

    var body: some View {
        HStack(alignment: .center, spacing: ResponsiveDesign.spacing(0)) {
            // Column 1: Year label
            Text(String(format: "%d", self.year))
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.inputFieldText)
                .frame(width: ResponsiveDesign.spacing(50), alignment: .leading)
                .padding(.horizontal, 2)

            // Column 2: Empty KW column
            Text("")
                .frame(width: ResponsiveDesign.spacing(40), alignment: .center)

            // Column 3: Empty return column
            Spacer(minLength: ResponsiveDesign.spacing(200))
        }
        .frame(height: ResponsiveDesign.spacing(44))
        .background(AppTheme.sectionBackground)

        // Horizontal separator
        Rectangle()
            .fill(Color.white.opacity(0.6))
            .frame(height: 1)
    }
}

#Preview {
    YearSeparatorRow(year: 2_024)
        .background(AppTheme.screenBackground)
}











