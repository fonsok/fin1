import SwiftUI

struct PositionDetailView: View {
    let position: MockPosition
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack {
                    Text("Position Details")
                        .font(ResponsiveDesign.titleFont())
                        .foregroundColor(AppTheme.fontColor)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        self.dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }
}

#Preview {
    PositionDetailView(position: mockPositions[0])
}











