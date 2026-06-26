import SwiftUI

/// Scrollable legal text that only reports "read to end" after the user scrolls within this view.
/// Uses scroll geometry (not `onAppear`) so nested parent `ScrollView`s cannot falsely satisfy the gate.
struct ScrollToAcceptReader<Content: View>: View {
    @Binding var hasReachedBottom: Bool
    let content: () -> Content

    private let bottomThreshold: CGFloat = 24
    private let minimumScrollOffset: CGFloat = 8

    init(
        hasReachedBottom: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._hasReachedBottom = hasReachedBottom
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(0)) {
                self.content()
                Color.clear
                    .frame(height: 1)
                    .padding(.bottom, ResponsiveDesign.spacing(24))
            }
        }
        .scrollIndicators(.visible)
        .onScrollGeometryChange(for: ScrollToAcceptGeometry.self) { geometry in
            ScrollToAcceptGeometry(
                contentHeight: geometry.contentSize.height,
                visibleBottom: geometry.contentOffset.y + geometry.containerSize.height,
                scrollOffset: geometry.contentOffset.y
            )
        } action: { _, geometry in
            guard !self.hasReachedBottom else { return }
            let fitsWithoutScrolling = geometry.contentHeight <= geometry.visibleBottom + self.bottomThreshold
            let scrolledToEnd = geometry.visibleBottom >= geometry.contentHeight - self.bottomThreshold
            let userScrolled = geometry.scrollOffset > self.minimumScrollOffset
            if scrolledToEnd && (userScrolled || fitsWithoutScrolling) {
                self.hasReachedBottom = true
            }
        }
    }
}

private struct ScrollToAcceptGeometry: Equatable {
    let contentHeight: CGFloat
    let visibleBottom: CGFloat
    let scrollOffset: CGFloat
}

extension View {
    /// Wraps scrollable legal content and reports when the user scrolls to the end inside this container.
    func scrollToAcceptContainer(hasReachedBottom: Binding<Bool>) -> some View {
        ScrollToAcceptReader(hasReachedBottom: hasReachedBottom) {
            self
        }
    }
}
