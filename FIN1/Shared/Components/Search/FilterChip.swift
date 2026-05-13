import SwiftUI

// MARK: - Filter Chip Components

struct FilterChip: View {
    let label: String
    let value: String
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(6)) {
            Text(self.value)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.regular)
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
            Button(action: self.onClear, label: {
                Image(systemName: "xmark")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.7))
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
        Button(action: self.onTap, label: {
            HStack {
                Text(self.value ?? self.label)
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

// MARK: - Wrapping chip row (Layout protocol — no GeometryProxy / alignmentGuide concurrency issues)

/// Lays out subviews left-to-right, wrapping to the next row when a line exceeds the proposed width.
private struct HorizontalChipFlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        self.layoutFrames(proposal: proposal, subviews: subviews).bounds.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = self.layoutFrames(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let frame = result.frames[index]
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func layoutFrames(proposal: ProposedViewSize, subviews: Subviews) -> (frames: [CGRect], bounds: CGRect) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude

        for subview in subviews {
            let ideal = subview.sizeThatFits(.unspecified)
            if x + ideal.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + self.spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: ideal))
            rowHeight = max(rowHeight, ideal.height)
            x += ideal.width + self.spacing
        }

        let totalHeight = y + rowHeight
        let totalWidth = frames.map(\.maxX).max() ?? 0
        let bounds = CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight)
        return (frames, bounds)
    }
}

struct ChipFlowLayout: View {
    @Binding var strikePriceGap: String?
    @Binding var remainingTerm: String?
    @Binding var issuer: String?

    private var chipSpacing: CGFloat { ResponsiveDesign.spacing(8) }

    var body: some View {
        HorizontalChipFlowLayout(spacing: self.chipSpacing) {
            if let val = strikePriceGap {
                FilterChip(label: "Strike Price Gap", value: val, onClear: { self.strikePriceGap = nil })
                    .padding(ResponsiveDesign.spacing(4))
            }
            if let val = remainingTerm {
                FilterChip(label: "Restlaufzeit", value: val, onClear: { self.remainingTerm = nil })
                    .padding(ResponsiveDesign.spacing(4))
            }
            if let val = issuer {
                FilterChip(label: "Emittent", value: val, onClear: { self.issuer = nil })
                    .padding(ResponsiveDesign.spacing(4))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
