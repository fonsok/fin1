import SwiftUI

// MARK: - Order Placed Overlay
/// Shared overlay component that shows when an order is successfully placed
struct OrderPlacedOverlay: View {
    let orderType: OrderType
    let onDismiss: (() -> Void)?

    init(orderType: OrderType = .buy, onDismiss: (() -> Void)? = nil) {
        self.orderType = orderType
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            // Overlay content
            VStack(spacing: ResponsiveDesign.spacing(20)) {
                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 3))
                    .foregroundColor(AppTheme.accentGreen)

                // Title - specific to order type
                Text(self.titleText)
                    .font(ResponsiveDesign.titleFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
                    .multilineTextAlignment(.center)

                // Subtitle
                Text(self.subtitleText)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.accentGreen)
                    .multilineTextAlignment(.center)

                // Info text
                Text(self.infoText)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ResponsiveDesign.spacing(20))

                // Auto-navigation indicator
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accentGreen))
                        .scaleEffect(0.8)

                    Text("Weiterleitung zum Depot...")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }
            }
            .padding(ResponsiveDesign.spacing(32))
            .background(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(16))
                    .fill(AppTheme.sectionBackground)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal, ResponsiveDesign.spacing(40))
        }
        .animation(.easeInOut(duration: 0.3), value: true)
    }

    // MARK: - Computed Properties

    private var titleText: String {
        switch self.orderType {
        case .buy:
            return "Kauf-Order erfolgreich platziert!"
        case .sell:
            return "Verkauf-Order erfolgreich platziert!"
        }
    }

    private var subtitleText: String {
        switch self.orderType {
        case .buy:
            return "Ihre Kauf-Order wurde übermittelt"
        case .sell:
            return "Ihre Verkauf-Order wurde übermittelt"
        }
    }

    private var infoText: String {
        switch self.orderType {
        case .buy:
            return "Die Order erscheint nun in den laufenden Transaktionen. Sie werden automatisch zum Depot weitergeleitet."
        case .sell:
            return "Die Order erscheint nun in den laufenden Transaktionen. Sie werden automatisch zum Depot weitergeleitet."
        }
    }
}

// MARK: - Order Type
// Using existing OrderType enum from FIN1/Features/Trader/Models/Order.swift

#if DEBUG
struct OrderPlacedOverlay_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            OrderPlacedOverlay(orderType: .buy)
            OrderPlacedOverlay(orderType: .sell)
        }
        .background(AppTheme.screenBackground)
    }
}
#endif
