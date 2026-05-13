import Foundation
import SwiftUI

// MARK: - Stat Item Component
// Reusable component for displaying statistics with title and value
struct StatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(4)) {
            Text(self.value)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            Text(self.title)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
}
