import SwiftUI

/// Button for bulk action toolbar.
struct BulkActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ResponsiveDesign.spacing(6)) {
                Image(systemName: icon)
                    .font(ResponsiveDesign.captionFont())
                Text(title)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, ResponsiveDesign.spacing(16))
            .padding(.vertical, ResponsiveDesign.spacing(10))
            .background(color)
            .cornerRadius(ResponsiveDesign.spacing(20))
        }
    }
}
