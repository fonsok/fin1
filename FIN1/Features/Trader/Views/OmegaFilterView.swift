import SwiftUI

struct OmegaFilterView: View {
    @Binding var selectedOmega: String?
    @Environment(\.dismiss) private var dismiss

    // Sample Omega values
    private let omegaOptions = [
        "Alle",
        "0.1 - 0.5",
        "0.5 - 1.0",
        "1.0 - 2.0",
        "2.0 - 5.0",
        "5.0+"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    Text("Omega Filter")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)
                        .padding(.top, ResponsiveDesign.spacing(20))

                    LazyVStack(spacing: ResponsiveDesign.spacing(12)) {
                        ForEach(omegaOptions, id: \.self) { option in
                            Button(action: {
                                selectedOmega = option == "Alle" ? nil : option
                                dismiss()
                            }) {
                                HStack {
                                    Text(option)
                                        .font(ResponsiveDesign.bodyFont())
                                        .foregroundColor(AppTheme.fontColor)

                                    Spacer()

                                    if (selectedOmega == option) || (selectedOmega == nil && option == "Alle") {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(AppTheme.accentGreen)
                                    }
                                }
                                .padding(ResponsiveDesign.spacing(16))
                                .background(AppTheme.sectionBackground)
                                .cornerRadius(ResponsiveDesign.spacing(8))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(16))

                    Spacer()
                }
            }
            .navigationTitle("Omega")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    OmegaFilterView(selectedOmega: .constant(nil))
}
