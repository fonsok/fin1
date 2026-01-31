import SwiftUI

struct RemainingTermView: View {
    @Binding var selectedLaufzeit: String?
    @Environment(\.dismiss) private var dismiss

    let options: [String] = ["< 4 Wochen", "< 6 Monate", "< 1 Jahr"]

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            VStack(spacing: ResponsiveDesign.spacing(20)) {
                Text("Restlaufzeit OS")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                Divider()

                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    ForEach(options, id: \.self) { option in
                        Button(action: { selectedLaufzeit = option }, label: {
                            Text(option)
                                .foregroundColor(AppTheme.fontColor)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(selectedLaufzeit == option ? AppTheme.accentGreen : AppTheme.sectionBackground)
                                .cornerRadius(ResponsiveDesign.spacing(8))
                        })
                    }
                }

                Spacer()

                Button(action: { dismiss() }, label: {
                    Text("übernehmen")
                        .foregroundColor(AppTheme.fontColor)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.buttonColor)
                        .cornerRadius(ResponsiveDesign.spacing(8))
                })
            }
            .padding()
        }
    }
}

#Preview {
    RemainingTermView(selectedLaufzeit: .constant("< 4 Wochen"))
}
