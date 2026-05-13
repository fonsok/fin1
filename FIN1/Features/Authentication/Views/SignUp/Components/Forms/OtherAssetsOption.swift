import SwiftUI

struct OtherAssetsOption: View {
    let title: String
    @Binding var isSelected: Bool

    var body: some View {
        Button(action: { self.isSelected.toggle() }, label: {
            HStack {
                // Clean square checkbox - double size, no borders
                Rectangle()
                    .fill(self.isSelected ? AppTheme.accentGreen : AppTheme.inputFieldBackground)
                    .frame(width: 32, height: 32) // Double the size
                    .overlay(
                        Group {
                            if self.isSelected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppTheme.fontColor)
                                    .font(ResponsiveDesign.scaledSystemFont(size: 18, weight: .bold))
                            }
                        }
                    )

                Text(self.title)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
        })
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack(spacing: ResponsiveDesign.spacing(8)) {
        OtherAssetsOption(title: "Real estate", isSelected: .constant(true))
        OtherAssetsOption(title: "Gold, silver", isSelected: .constant(false))
        OtherAssetsOption(title: "No", isSelected: .constant(false))
    }
    .padding()
    .background(AppTheme.screenBackground)
}
