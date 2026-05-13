import SwiftUI

// MARK: - Unified Order Action Button Component
/// Shared component for order action buttons (Buy/Sell)
struct OrderActionButton: View {
    let title: String
    let backgroundColor: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: self.action, label: {
            Text(self.title)
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "#F5F5F5"))
                .frame(maxWidth: .infinity)
                .padding()
                .background(self.backgroundColor)
                .cornerRadius(ResponsiveDesign.spacing(10))
        })
        .buttonStyle(PlainButtonStyle())
        .disabled(!self.isEnabled)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: ResponsiveDesign.spacing(16)) {
        OrderActionButton(
            title: "(Gebührenpflichtig) Kaufen",
            backgroundColor: AppTheme.buttonColor,
            isEnabled: true,
            action: {}
        )

        OrderActionButton(
            title: "(Gebührenpflichtig) Verkaufen",
            backgroundColor: AppTheme.buttonColor,
            isEnabled: false,
            action: {}
        )
    }
    .padding()
    .background(AppTheme.screenBackground)
}
