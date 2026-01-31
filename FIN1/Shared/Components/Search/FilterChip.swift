import SwiftUI

// MARK: - Filter Chip Components

struct FilterChip: View {
    let label: String
    let value: String
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(6)) {
            Text(value)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.regular)
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
            Button(action: onClear, label: {
                Image(systemName: "xmark")
                    .font(.system(size: ResponsiveDesign.iconSize() * 0.7))
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
            })
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

struct FilterChipButton: View {
    let label: String
    let value: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap, label: {
            HStack {
                Text(value ?? label)
                    .foregroundColor(AppTheme.inputFieldText)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(AppTheme.inputFieldText)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(AppTheme.inputFieldBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        })
        .buttonStyle(PlainButtonStyle())
    }
}

struct ChipFlowLayout: View {
    @Binding var strikePriceGap: String?
    @Binding var remainingTerm: String?
    @Binding var issuer: String?

    @State private var totalHeight = CGFloat.zero

    var body: some View {
        var chips: [(label: String, value: String, onClear: () -> Void)] = []
        if let val = strikePriceGap { chips.append(("Strike Price Gap", val, { strikePriceGap = nil })) }
        if let val = remainingTerm { chips.append(("Restlaufzeit", val, { remainingTerm = nil })) }
        if let val = issuer { chips.append(("Emittent", val, { issuer = nil })) }

        let content = VStack {
            GeometryReader { geometry in
                self.generateContent(in: geometry, chips: chips)
            }
        }

        return content.frame(height: totalHeight)
    }

    private func generateContent(in g: GeometryProxy, chips: [(label: String, value: String, onClear: () -> Void)]) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(chips.indices, id: \.self) { index in
                let chip = chips[index]
                FilterChip(label: chip.label, value: chip.value, onClear: chip.onClear)
                    .padding(.all, 4)
                    .alignmentGuide(.leading, computeValue: { d in
                        if abs(width - d.width) > g.size.width {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if index == chips.count - 1 {
                            width = 0 // Last item
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { _ in
                        let result = height
                        if index == chips.count - 1 {
                            height = 0 // Last item
                        }
                        return result
                    })
            }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        return GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)
            DispatchQueue.main.async {
                binding.wrappedValue = rect.size.height
            }
            return .clear
        }
    }
}

#Preview {
    VStack(spacing: ResponsiveDesign.spacing(16)) {
        FilterChip(label: "Emittent", value: "Société Générale", onClear: {})
        FilterChipButton(label: "Restlaufzeit", value: "< 4 Wo.", onTap: {})
        ChipFlowLayout(
            strikePriceGap: .constant("Am Geld"),
            remainingTerm: .constant("< 4 Wo."),
            issuer: .constant("Société Générale")
        )
    }
    .padding()
    .background(AppTheme.screenBackground)
}
