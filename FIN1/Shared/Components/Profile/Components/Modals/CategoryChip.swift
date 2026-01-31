import SwiftUI

/// Reusable category chip for filtering FAQs
struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: ResponsiveDesign.spacing(4)) {
                Image(systemName: icon)
                    .font(ResponsiveDesign.captionFont())

                Text(title)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundColor(isSelected ? AppTheme.screenBackground : AppTheme.fontColor)
            .padding(.horizontal, ResponsiveDesign.spacing(12))
            .padding(.vertical, ResponsiveDesign.spacing(8))
            .frame(maxWidth: .infinity)
            .background(isSelected ? AppTheme.accentLightBlue : AppTheme.systemTertiaryBackground)
            .cornerRadius(ResponsiveDesign.spacing(20))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    HStack {
        CategoryChip(
            title: "All",
            icon: "list.bullet",
            isSelected: true,
            action: {}
        )
        CategoryChip(
            title: "Investments",
            icon: "dollarsign.circle.fill",
            isSelected: false,
            action: {}
        )
    }
    .padding()
    .background(AppTheme.screenBackground)
}





