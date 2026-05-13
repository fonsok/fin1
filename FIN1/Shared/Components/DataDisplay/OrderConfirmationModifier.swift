import SwiftUI

// MARK: - Order Confirmation Overlay Modifier
/// Shared modifier for order confirmation overlay to eliminate DRY violation
struct OrderConfirmationOverlayModifier: ViewModifier {
    let orderType: OrderType
    let isShowing: Bool
    let onDismiss: () -> Void
    let onNavigateToDepot: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay(
                // Order placed overlay
                Group {
                    if self.isShowing {
                        OrderPlacedOverlay(orderType: self.orderType) {
                            // Callback when overlay is dismissed
                            withAnimation(.easeOut(duration: 0.3)) {
                                self.onDismiss()
                            }
                        }
                        .transition(.opacity.combined(with: .scale))
                        .onAppear {
                            print("🎯 OrderConfirmationOverlay appeared for \(self.orderType)")
                            // Auto-hide overlay after 2.5 seconds to allow user to read the message
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                print("🎯 OrderConfirmationOverlay: Dismissing overlay and navigating to depot")
                                withAnimation(.easeOut(duration: 0.3)) {
                                    self.onDismiss()
                                }
                                // Navigate to depot after overlay is dismissed
                                self.onNavigateToDepot()
                            }
                        }
                    }
                }
            )
    }
}

// MARK: - View Extension
extension View {
    /// Adds order confirmation overlay with automatic navigation to depot
    /// - Parameters:
    ///   - orderType: The type of order (buy/sell)
    ///   - isShowing: Whether the overlay should be shown
    ///   - onDismiss: Callback when overlay is dismissed
    ///   - onNavigateToDepot: Callback to navigate to depot tab
    func orderConfirmationOverlay(
        orderType: OrderType,
        isShowing: Bool,
        onDismiss: @escaping () -> Void,
        onNavigateToDepot: @escaping () -> Void
    ) -> some View {
        self.modifier(OrderConfirmationOverlayModifier(
            orderType: orderType,
            isShowing: isShowing,
            onDismiss: onDismiss,
            onNavigateToDepot: onNavigateToDepot
        ))
    }
}

#if DEBUG
struct OrderConfirmationOverlayModifier_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Buy Order View")
                .orderConfirmationOverlay(
                    orderType: .buy,
                    isShowing: true,
                    onDismiss: {},
                    onNavigateToDepot: {}
                )

            Text("Sell Order View")
                .orderConfirmationOverlay(
                    orderType: .sell,
                    isShowing: true,
                    onDismiss: {},
                    onNavigateToDepot: {}
                )
        }
        .background(AppTheme.screenBackground)
    }
}
#endif
