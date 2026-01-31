import SwiftUI

// MARK: - Trade Detail Item
struct TradeDetailItem: View {
    let title: String
    let value: String
    var isPositive: Bool = false
    var showInfoIcon: Bool = false
    var onInfoTapped: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            HStack(spacing: ResponsiveDesign.spacing(4)) {
                Text(title)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))

                if showInfoIcon {
                    Button(action: {
                        onInfoTapped?()
                    }, label: {
                        Image(systemName: "info.circle")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.accentLightBlue)
                    })
                }
            }

            Text(value)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(isPositive ? AppTheme.accentGreen : AppTheme.fontColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
