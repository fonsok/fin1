import SwiftUI

struct AdvancedFiltersView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Text("Advanced Filters")
                    .font(ResponsiveDesign.titleFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)

                Text("Additional filtering options will be implemented here")
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                Spacer()
            }
            .responsivePadding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { self.dismiss() }
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }
}

#Preview {
    AdvancedFiltersView()
}
