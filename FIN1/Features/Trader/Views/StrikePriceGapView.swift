import SwiftUI

struct StrikePriceGapView: View {
    @Binding var selectedGap: String?
    @Environment(\.dismiss) private var dismiss

    let options: [(String, String)] = [
        ("im Geld", "+ 5 %"),
        ("am Geld", "-1 bis +1 %"),
        ("aus dem Geld", "- 5 %")
    ]

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            VStack(spacing: ResponsiveDesign.spacing(20)) {
                Text("Strike Price Gap")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                Divider()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(options, id: \.0) { option in
                        Button(action: { selectedGap = option.0 }, label: {
                            VStack {
                                Text(option.0)
                                Text(option.1)
                                    .font(ResponsiveDesign.captionFont())
                            }
                            .foregroundColor(AppTheme.fontColor)
                            .padding()
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(selectedGap == option.0 ? AppTheme.accentGreen : AppTheme.sectionBackground)
                            .cornerRadius(ResponsiveDesign.spacing(8))
                        })
                    }
                }

                HStack(spacing: ResponsiveDesign.spacing(16)) {
                    TextField("von", text: .constant(""))
                        .padding()
                        .background(AppTheme.sectionBackground)
                        .cornerRadius(ResponsiveDesign.spacing(8))
                        .foregroundColor(AppTheme.fontColor)

                    TextField("bis", text: .constant(""))
                        .padding()
                        .background(AppTheme.sectionBackground)
                        .cornerRadius(ResponsiveDesign.spacing(8))
                        .foregroundColor(AppTheme.fontColor)
                }

                Button(action: { dismiss() }, label: {
                    Text("übernehmen")
                        .foregroundColor(AppTheme.fontColor)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.buttonColor)
                        .cornerRadius(ResponsiveDesign.spacing(8))
                })

                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    StrikePriceGapView(selectedGap: .constant("am Geld"))
}
