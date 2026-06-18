import SwiftUI

// MARK: - Shared striped list layout (sign-up, dashboard, learning pages, …)
//
// Single source for zebra row backgrounds and section padding.
// Feature modules may expose domain aliases (e.g. `signUpListSection`) — logic stays here.

enum StripedListStyle {
    @ViewBuilder
    @MainActor
    static func listRowBackground(index: Int) -> some View {
        ZStack {
            AppTheme.screenBackground
            if index.isMultiple(of: 2) {
                Color.white.opacity(0.035)
            } else {
                Color.black.opacity(0.03)
            }
        }
    }
}

struct StripedListSectionModifier: ViewModifier {
    let stripeIndex: Int
    var isSelected: Bool
    var selectionAccent: Color
    var bandTint: Color?
    /// When set, replaces the default screen zebra with a solid full-width band (e.g. data-table rows).
    var solidBackground: Color?
    var verticalPadding: CGFloat?

    init(
        stripeIndex: Int,
        isSelected: Bool = false,
        selectionAccent: Color = AppTheme.accentLightBlue,
        bandTint: Color? = nil,
        solidBackground: Color? = nil,
        verticalPadding: CGFloat? = nil
    ) {
        self.stripeIndex = stripeIndex
        self.isSelected = isSelected
        self.selectionAccent = selectionAccent
        self.bandTint = bandTint
        self.solidBackground = solidBackground
        self.verticalPadding = verticalPadding
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, ResponsiveDesign.mainHorizontalPadding())
            .padding(.vertical, self.verticalPadding ?? ResponsiveDesign.spacing(20))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    if let solidBackground {
                        solidBackground
                    } else {
                        StripedListStyle.listRowBackground(index: self.stripeIndex)
                    }
                    if let bandTint {
                        bandTint.opacity(0.1)
                    }
                    if self.isSelected {
                        self.selectionAccent.opacity(0.12)
                    }
                }
            }
    }
}

extension View {
    /// Full-width list row with alternating stripe on the screen background.
    func stripedListSection(
        stripeIndex: Int,
        isSelected: Bool = false,
        selectionAccent: Color = AppTheme.accentLightBlue,
        bandTint: Color? = nil,
        solidBackground: Color? = nil,
        verticalPadding: CGFloat? = nil
    ) -> some View {
        self.modifier(
            StripedListSectionModifier(
                stripeIndex: stripeIndex,
                isSelected: isSelected,
                selectionAccent: selectionAccent,
                bandTint: bandTint,
                solidBackground: solidBackground,
                verticalPadding: verticalPadding
            )
        )
    }
}

/// Stacks sections edge-to-edge (no spacing, no outer card wrapper).
struct StripedStepList<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            self.content()
        }
    }
}

/// Padded content block on screen background — for form-heavy flows without zebra stripes.
struct PaddedFormSectionList<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(20)) {
            self.content()
        }
        .padding(.horizontal, ResponsiveDesign.mainHorizontalPadding())
        .padding(.vertical, ResponsiveDesign.spacing(20))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
