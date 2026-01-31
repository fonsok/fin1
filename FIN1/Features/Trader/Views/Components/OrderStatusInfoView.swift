import SwiftUI

// MARK: - Order Status Info View
/// Displays order status legend information
struct OrderStatusInfoView: View {
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Order-Status")
                .font(ResponsiveDesign.headlineFont())
            HStack { Text("1 =").bold(); Text("übermittelt") }
            HStack { Text("2 =").bold(); Text("Handel ausgesetzt") }
            HStack { Text("3 =").bold(); Text("ausgeführt") }
            HStack { Text("4 =").bold(); Text("abgeschlossen") }
        }
        .foregroundColor(AppTheme.fontColor)
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

// MARK: - Preview
#Preview {
    OrderStatusInfoView()
        .responsivePadding()
        .background(AppTheme.screenBackground)
}
