import SwiftUI

// MARK: - Order View Modifiers
/// Shared view modifiers for order-related views to eliminate code duplication

// MARK: - Order Navigation Modifier
/// Handles automatic navigation to depot view when orders are placed
struct OrderNavigationModifier: ViewModifier {
    @Binding var shouldShowDepotView: Bool
    let tabRouter: TabRouter

    func body(content: Content) -> some View {
        content
            .onChange(of: self.shouldShowDepotView) { _, newValue in
                if newValue {
                    // Navigate to depot tab when automatic order is placed
                    self.tabRouter.selectedTab = 2 // Depot tab
                    self.shouldShowDepotView = false // Reset the flag
                }
            }
    }
}

// MARK: - Order Type Change Modifier
/// Handles order type changes and limit order monitoring
struct OrderTypeChangeModifier<T: RawRepresentable & CaseIterable & Equatable>: ViewModifier where T.RawValue == String {
    let orderType: T
    let limit: String
    let limitPrice: Double?
    let onStopMonitoring: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: self.orderType) { _, newValue in
                // Stop monitoring if switching away from limit order
                if newValue.rawValue != "Limit" {
                    self.onStopMonitoring()
                }
            }
            .onChange(of: self.limit) { _, _ in
                // Stop monitoring if limit price is cleared
                if self.orderType.rawValue == "Limit" && self.limitPrice == nil {
                    self.onStopMonitoring()
                }
            }
    }
}

// MARK: - Order Action Modifier
/// Handles order placement and navigation
struct OrderActionModifier: ViewModifier {
    let onPlaceOrder: () async -> Void
    let tabRouter: TabRouter
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                Task {
                    await self.onPlaceOrder()
                    // Navigate to depot tab and dismiss the view
                    self.tabRouter.selectedTab = 2 // Depot tab
                    self.onDismiss()
                }
            }
    }
}

// MARK: - View Extensions
extension View {
    /// Adds order navigation functionality to a view
    /// - Parameters:
    ///   - shouldShowDepotView: Binding to track when to show depot view
    ///   - tabRouter: Tab router for navigation
    /// - Returns: View with order navigation modifier
    func orderNavigation(
        shouldShowDepotView: Binding<Bool>,
        tabRouter: TabRouter
    ) -> some View {
        self.modifier(OrderNavigationModifier(
            shouldShowDepotView: shouldShowDepotView,
            tabRouter: tabRouter
        ))
    }

    /// Adds order type change handling to a view
    /// - Parameters:
    ///   - orderType: Current order type
    ///   - limit: Current limit price string
    ///   - limitPrice: Parsed limit price
    ///   - onStopMonitoring: Callback when monitoring should stop
    /// - Returns: View with order type change modifier
    func orderTypeChangeHandling<T: RawRepresentable & CaseIterable & Equatable>(
        orderType: T,
        limit: String,
        limitPrice: Double?,
        onStopMonitoring: @escaping () -> Void
    ) -> some View where T.RawValue == String {
        self.modifier(OrderTypeChangeModifier(
            orderType: orderType,
            limit: limit,
            limitPrice: limitPrice,
            onStopMonitoring: onStopMonitoring
        ))
    }

    /// Adds order action handling to a view
    /// - Parameters:
    ///   - onPlaceOrder: Async callback for placing order
    ///   - tabRouter: Tab router for navigation
    ///   - onDismiss: Callback for dismissing view
    /// - Returns: View with order action modifier
    func orderAction(
        onPlaceOrder: @escaping () async -> Void,
        tabRouter: TabRouter,
        onDismiss: @escaping () -> Void
    ) -> some View {
        self.modifier(OrderActionModifier(
            onPlaceOrder: onPlaceOrder,
            tabRouter: tabRouter,
            onDismiss: onDismiss
        ))
    }
}

// MARK: - Combined Order Modifiers
extension View {
    /// Adds all order-related modifiers in one call
    /// - Parameters:
    ///   - shouldShowDepotView: Binding to track when to show depot view
    ///   - orderType: Current order type
    ///   - limit: Current limit price string
    ///   - limitPrice: Parsed limit price
    ///   - onStopMonitoring: Callback when monitoring should stop
    ///   - tabRouter: Tab router for navigation
    /// - Returns: View with all order modifiers applied
    func orderModifiers<T: RawRepresentable & CaseIterable & Equatable>(
        shouldShowDepotView: Binding<Bool>,
        orderType: T,
        limit: String,
        limitPrice: Double?,
        onStopMonitoring: @escaping () -> Void,
        tabRouter: TabRouter
    ) -> some View where T.RawValue == String {
        self
            .orderNavigation(shouldShowDepotView: shouldShowDepotView, tabRouter: tabRouter)
            .orderTypeChangeHandling(
                orderType: orderType,
                limit: limit,
                limitPrice: limitPrice,
                onStopMonitoring: onStopMonitoring
            )
    }
}
