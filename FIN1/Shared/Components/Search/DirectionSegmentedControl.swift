import SwiftUI

struct DirectionSegmentedControl: View {
    @Binding var selection: SecuritiesSearchView.Direction

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let totalHeight = geometry.size.height
            let segmentWidth = max((totalWidth - 4) / 2, 0)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                    .fill(AppTheme.sectionBackground)

                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                    .fill(AppTheme.accentGreen.opacity(0.7))
                    .frame(width: segmentWidth, height: max(totalHeight - 4, 0))
                    .offset(x: self.selection == .call ? 2 : segmentWidth + 2)
                    .animation(.easeInOut(duration: 0.2), value: self.selection)

                HStack(spacing: ResponsiveDesign.spacing(0)) {
                    self.segment(title: "Call", isActive: self.selection == .call) {
                        withAnimation(.easeInOut(duration: 0.2)) { self.selection = .call }
                    }
                    .frame(width: segmentWidth, height: totalHeight)

                    self.segment(title: "Put", isActive: self.selection == .put) {
                        withAnimation(.easeInOut(duration: 0.2)) { self.selection = .put }
                    }
                    .frame(width: segmentWidth, height: totalHeight)
                }
            }
        }
        .frame(height: 36)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Richtung")
        .accessibilityValue(self.selection == .call ? "Call" : "Put")
    }

    private func segment(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action, label: {
            Text(title)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        })
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

#Preview {
    ZStack {
        AppTheme.screenBackground.ignoresSafeArea()
        StatefulPreviewWrapper(SecuritiesSearchView.Direction.call) { selection in
            DirectionSegmentedControl(selection: selection)
                .padding()
        }
    }
}

// Helper for preview stateful bindings
struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    private let content: (Binding<Value>) -> Content

    init(_ initialValue: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self._value = State(initialValue: initialValue)
        self.content = content
    }

    var body: some View {
        self.content(self.$value)
    }
}
