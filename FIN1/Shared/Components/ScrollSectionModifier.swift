import SwiftUI

// MARK: - ScrollSection Modifier
/// Legacy nested scroll card (screen → scroll section → section cards).
/// **Deprecated** — use `StripedStepList` / `stripedListSection()`. See `.cursor/rules/architecture.md`.
@available(*, deprecated, message: "Use StripedStepList and stripedListSection() for flat full-width layouts.")
struct ScrollSectionModifier: ViewModifier {
    let horizontalMargin: CGFloat  // Space OUTSIDE (from Layer 1 - Light Blue Area)
    let verticalMargin: CGFloat    // Space OUTSIDE (from Layer 1 - Light Blue Area)
    let cornerRadius: CGFloat
    
    init(horizontalMargin: CGFloat = 16, verticalMargin: CGFloat = 16, cornerRadius: CGFloat = 12) {
        self.horizontalMargin = horizontalMargin
        self.verticalMargin = verticalMargin
        self.cornerRadius = cornerRadius
    }
    
    func body(content: Content) -> some View {
        content
            .background(AppTheme.systemSecondaryBackground)  // Layer 2: ScrollSection
            .cornerRadius(self.cornerRadius)
            .padding(.horizontal, self.horizontalMargin) // MARGIN from Light Blue Area (Layer 1)
            .padding(.vertical, self.verticalMargin)     // MARGIN from Light Blue Area (Layer 1)
    }
}

// MARK: - View Extension
extension View {
    /// **Deprecated** — use `StripedStepList` / `stripedListSection()`.
    @available(*, deprecated, message: "Use StripedStepList and stripedListSection() for flat full-width layouts.")
    func scrollSection(
        horizontalMargin: CGFloat = 16, 
        verticalMargin: CGFloat = 16, 
        cornerRadius: CGFloat = 12
    ) -> some View {
        self.modifier(ScrollSectionModifier(
            horizontalMargin: horizontalMargin,
            verticalMargin: verticalMargin,
            cornerRadius: cornerRadius
        ))
    }
}
