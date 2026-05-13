import SwiftUI

struct OrderTypeSegmentedControl: View {
    @Binding var selection: OrderType

    enum OrderType: String, CaseIterable {
        case market = "Market"
        case limit = "Limit"
    }

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let totalHeight = geometry.size.height
            let segmentWidth = max((totalWidth - 4) / 2, 0)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                    .fill(AppTheme.sectionBackground)

                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                    .fill(AppTheme.accentLightBlue)
                    .frame(width: segmentWidth, height: max(totalHeight - 4, 0))
                    .offset(x: self.selection == .market ? 2 : segmentWidth + 2)
                    .animation(.easeInOut(duration: 0.2), value: self.selection)

                HStack(spacing: ResponsiveDesign.spacing(0)) {
                    self.segment(title: "Market", isActive: self.selection == .market) {
                        withAnimation(.easeInOut(duration: 0.2)) { self.selection = .market }
                    }
                    .frame(width: segmentWidth, height: totalHeight)

                    self.segment(title: "Limit", isActive: self.selection == .limit) {
                        withAnimation(.easeInOut(duration: 0.2)) { self.selection = .limit }
                    }
                    .frame(width: segmentWidth, height: totalHeight)
                }
            }
        }
        .frame(height: 36)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Order type")
        .accessibilityValue(self.selection == .market ? "Market" : "Limit")
    }

    private func segment(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action, label: {
            Text(title)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        })
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

#Preview {
    ZStack {
        AppTheme.screenBackground.ignoresSafeArea()
        StatefulPreviewWrapper(OrderTypeSegmentedControl.OrderType.market) { selection in
            OrderTypeSegmentedControl(selection: selection)
                .responsivePadding()
        }
    }
}
