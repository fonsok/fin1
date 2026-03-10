import SwiftUI

/// Category filter chip for canned response picker.
struct CannedResponseCategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ResponsiveDesign.spacing(4)) {
                Image(systemName: icon)
                    .font(ResponsiveDesign.captionFont())
                Text(title)
                    .font(ResponsiveDesign.captionFont())
            }
            .foregroundColor(isSelected ? .white : AppTheme.fontColor)
            .padding(.horizontal, ResponsiveDesign.spacing(12))
            .padding(.vertical, ResponsiveDesign.spacing(6))
            .background(isSelected ? AppTheme.accentLightBlue : AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(16))
        }
    }
}
