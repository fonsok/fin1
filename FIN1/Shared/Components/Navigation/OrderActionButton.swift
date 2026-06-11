import SwiftUI

// MARK: - Unified Order Action Button Component
/// Shared component for order action buttons (Buy/Sell)
struct OrderActionButton: View {
    let title: String
    let backgroundColor: Color
    let isEnabled: Bool
    var isLoading: Bool = false
    let action: () -> Void

    private var buttonTitle: String {
        self.isLoading ? "Wird übermittelt…" : self.title
    }

    var body: some View {
        Button(action: self.action, label: {
            HStack(spacing: ResponsiveDesign.spacing(8)) {
                if self.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#F5F5F5")))
                }
                Text(self.buttonTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "#F5F5F5"))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(self.backgroundColor.opacity(self.isEnabled || self.isLoading ? 1 : 0.5))
            .cornerRadius(ResponsiveDesign.spacing(10))
        })
        .buttonStyle(PlainButtonStyle())
        .disabled(!self.isEnabled || self.isLoading)
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
