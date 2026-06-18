import SwiftUI

struct ProfileSectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.systemSeparator)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

struct ProfileSectionTitle: View {
    let title: String

    var body: some View {
        HStack {
            Text(self.title)
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
