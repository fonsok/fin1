import SwiftUI

// MARK: - Depot Info Box
/// Reusable info box component for displaying depot information
struct DepotInfoBox: View {
    let title: String
    let value: String
    var backgroundColor: Color = AppTheme.sectionBackground
    var showInfoIcon: Bool = false
    var titleOpacity: Double = 0.75
    var valueOpacity: Double = 0.85

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.thin)
                    .foregroundColor(AppTheme.fontColor.opacity(titleOpacity))
                if showInfoIcon {
                    Spacer()
                    Image(systemName: "info.circle")
                        .foregroundColor(AppTheme.fontColor.opacity(titleOpacity))
                }
            }
            Text(value)
                .fontWeight(.regular)
                .foregroundColor(AppTheme.fontColor.opacity(valueOpacity))
        }
        .padding(ResponsiveDesign.spacing(8))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .cornerRadius(ResponsiveDesign.spacing(4))
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: ResponsiveDesign.spacing(8)) {
        DepotInfoBox(
            title: "Depot-Gesamtwert",
            value: "125.000,50 €"
        )

        DepotInfoBox(
            title: "Depot-Nr.",
            value: "DE12345678901234567890",
            showInfoIcon: true
        )

        DepotInfoBox(
            title: "Status",
            value: "Aktiv",
            backgroundColor: AppTheme.accentGreen.opacity(0.2)
        )
    }
    .responsivePadding()
    .background(AppTheme.screenBackground)
}
