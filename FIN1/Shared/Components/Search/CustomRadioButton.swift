import SwiftUI

struct CustomRadioButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action, label: {
            HStack(spacing: ResponsiveDesign.spacing(8)) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                    Circle()
                        .strokeBorder(Color.gray.opacity(0.5), lineWidth: 1)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(AppTheme.accentLightBlue)
                            .frame(width: 12, height: 12)
                    }
                }
                Text(title)
                    .foregroundColor(AppTheme.fontColor)
            }
        })
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack(spacing: ResponsiveDesign.spacing(16)) {
        CustomRadioButton(title: "Call", isSelected: true, action: {})
        CustomRadioButton(title: "Put", isSelected: false, action: {})
    }
    .padding()
    .background(AppTheme.screenBackground)
}
