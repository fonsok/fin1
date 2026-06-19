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
        .padding(.bottom, ResponsiveDesign.spacing(12))
    }
}

struct ProfileIconSectionTitle: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: self.icon)
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(self.color)
                .frame(width: 24)

            Text(self.title)
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, ResponsiveDesign.spacing(12))
    }
}
