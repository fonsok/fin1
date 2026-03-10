import SwiftUI

/// Reusable expandable section row component matching Terms layout
/// Used across Terms, FAQs, and Platform Advantages to ensure consistent UI
struct ExpandableSectionRow<Content: View>: View {
    let title: String
    let icon: String?
    let iconColor: Color
    let isExpanded: Bool
    let onToggle: () -> Void
    let content: () -> Content
    let titleFontWeight: Font.Weight
    let style: LandingViewModel.DesignStyle
    /// Optional override for the extra leading padding applied to expanded content (only for non-typewriter style).
    /// When `nil`, padding is calculated to align content with the header text (skipping the icon).
    let contentLeadingPaddingOverride: CGFloat?

    init(
        title: String,
        icon: String? = nil,
        iconColor: Color = AppTheme.accentLightBlue,
        isExpanded: Bool,
        onToggle: @escaping () -> Void,
        titleFontWeight: Font.Weight = .semibold,
        contentLeadingPaddingOverride: CGFloat? = nil,
        style: LandingViewModel.DesignStyle = .original,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.isExpanded = isExpanded
        self.onToggle = onToggle
        self.titleFontWeight = titleFontWeight
        self.contentLeadingPaddingOverride = contentLeadingPaddingOverride
        self.style = style
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader
            if isExpanded {
                sectionContent
            }
        }
        .cornerRadius(style == .typewriter ? 0 : ResponsiveDesign.spacing(12))
        .overlay(
            Group {
                if style != .typewriter {
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                        .stroke(AppTheme.fontColor.opacity(0.1), lineWidth: 1)
                }
            }
        )
    }

    private var sectionHeader: some View {
        Button(action: onToggle) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                if let icon = icon, style != .typewriter {
                    Image(systemName: icon)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(iconColor)
                        .frame(width: ResponsiveDesign.iconSize())
                }

                Text(title)
                    .font(style == .typewriter
                          ? .system(size: 16, weight: titleFontWeight == .semibold ? .bold : .regular, design: .monospaced)
                          : ResponsiveDesign.headlineFont())
                    .fontWeight(style == .typewriter ? (titleFontWeight == .semibold ? .bold : .regular) : titleFontWeight)
                    .foregroundColor(style == .typewriter ? Color("InputText") : AppTheme.fontColor)
                    .multilineTextAlignment(.leading)

                Spacer()

                chevronIcon
            }
            .padding(ResponsiveDesign.spacing(16))
            .background(style == .typewriter ? Color.clear : AppTheme.sectionBackground)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var chevronIcon: some View {
        Group {
            if style == .typewriter {
                Text(isExpanded ? "[-]" : "[+]")
                    .font(ResponsiveDesign.monospacedFont(size: 16, weight: .regular))
                    .foregroundColor(Color("InputText"))
            } else {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
            }
        }
    }

    private var sectionContent: some View {
        content()
            .padding(ResponsiveDesign.spacing(16))
            .padding(.leading, style == .typewriter ? 0 : effectiveContentLeadingPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(style == .typewriter ? Color.clear : AppTheme.systemTertiaryBackground)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    /// Calculates leading padding to align content text with header text
    private var calculatedContentLeadingPadding: CGFloat {
        if let _ = icon {
            // If icon exists: align with header text (icon width + spacing)
            return ResponsiveDesign.iconSize() + ResponsiveDesign.spacing(12)
        } else {
            // If no icon: align with header text (no extra padding needed)
            return 0
        }
    }

    private var effectiveContentLeadingPadding: CGFloat {
        contentLeadingPaddingOverride ?? calculatedContentLeadingPadding
    }

}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: ResponsiveDesign.spacing(16)) {
        ExpandableSectionRow(
            title: "Example Section",
            icon: "doc.text.fill",
            iconColor: AppTheme.accentLightBlue,
            isExpanded: true,
            onToggle: {},
            style: .original
        ) {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Text("This is expandable content")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.9))
            }
        }

        ExpandableSectionRow(
            title: "Typewriter Style",
            icon: nil,
            iconColor: AppTheme.accentLightBlue,
            isExpanded: true,
            onToggle: {},
            style: .typewriter
        ) {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Text("This is expandable content")
                    .font(ResponsiveDesign.monospacedFont(size: 16, weight: .regular))
                    .foregroundColor(.black)
            }
        }
    }
    .padding()
    .background(AppTheme.screenBackground)
}
#endif

