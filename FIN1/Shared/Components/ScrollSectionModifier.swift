import SwiftUI

// MARK: - ScrollSection Modifier
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
            .cornerRadius(cornerRadius)
            .padding(.horizontal, horizontalMargin) // MARGIN from Light Blue Area (Layer 1)
            .padding(.vertical, verticalMargin)     // MARGIN from Light Blue Area (Layer 1)
    }
}

// MARK: - View Extension
extension View {
    /// Creates a ScrollSection with proper margin from Light Blue Area
    /// - Parameters:
    ///   - horizontalMargin: Space OUTSIDE the scrollsection (from light blue area)
    ///   - verticalMargin: Space OUTSIDE the scrollsection (from light blue area)
    ///   - cornerRadius: Corner radius for the scrollsection
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
