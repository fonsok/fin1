import SwiftUI

// MARK: - Depot Header View
/// Displays depot value and depot number information
struct DepotHeaderView: View {
    let depotValue: Double
    let depotNumber: String
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Text("Depot-Gesamtwert")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                Text(self.depotValue.formattedAsLocalizedCurrency())
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                Spacer()
            }
            Text("Depot-Nr. \(self.depotNumber)")
                .font(ResponsiveDesign.bodyFont())
        }
        .foregroundColor(AppTheme.fontColor)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview
#Preview {
    DepotHeaderView(
        depotValue: 125_000.50,
        depotNumber: "DE12345678901234567890"
    )
    .responsivePadding()
    .background(AppTheme.screenBackground)
}
