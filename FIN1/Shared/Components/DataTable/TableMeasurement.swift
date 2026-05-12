import SwiftUI

// MARK: - Table Measurement Utilities

/// PreferenceKey to collect intrinsic widths per column across the view tree
struct ColumnWidthPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        let next = nextValue()
        for (key, width) in next {
            value[key] = max(value[key] ?? 0, width)
        }
    }
}

/// A helper view modifier to measure the intrinsic width of a view
struct MeasureWidth: ViewModifier {
    let columnKey: String

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: ColumnWidthPreferenceKey.self,
                                    value: [columnKey: proxy.size.width])
                }
            )
    }
}

extension View {
    /// Attaches a measurement hook for intrinsic width under the provided column key.
    func measureWidth(column key: String) -> some View {
        self.modifier(MeasureWidth(columnKey: key))
    }
}
