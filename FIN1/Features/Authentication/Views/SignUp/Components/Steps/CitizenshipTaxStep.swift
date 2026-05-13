import SwiftUI

// Import UI components
// Note: These components are now in the UI subfolder

struct CitizenshipTaxStep: View {
    @Binding var isNotUSCitizen: Bool
    @Binding var nationality: String
    @Binding var taxNumber: String
    @Binding var additionalResidenceCountry: String
    @Binding var additionalTaxNumber: String
    @Binding var address: String
    @Binding var showAdditionalFields: Bool

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(24)) {
            Text("Staatsbürgerschaft - Steuer")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
                .multilineTextAlignment(.center)

            // US Citizenship Declaration
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                HStack {
                    Button(action: { self.isNotUSCitizen = true }, label: {
                        HStack {
                            InteractiveElement(
                                isSelected: self.isNotUSCitizen,
                                type: .confirmationCircle
                            )

                            Text("Ich bin kein US Staatsbürger und auch nicht in den USA geboren.")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor)
                                .multilineTextAlignment(.leading)

                            Spacer()
                        }
                    })
                    .buttonStyle(PlainButtonStyle())
                }
                .responsivePadding()
                .background(self.isNotUSCitizen ? AppTheme.accentGreen.opacity(0.1) : AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(12))
                .overlay(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                        .stroke(self.isNotUSCitizen ? AppTheme.accentGreen : Color.clear, lineWidth: 2)
                )
            }
            .responsivePadding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(16))

            // Citizenship & Tax Information (unified section)
            VStack(spacing: ResponsiveDesign.spacing(20)) {
                Text("Staatsangehörigkeit & Steuer")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Primary fields
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    LabeledInputField(
                        label: "Staatsangehörigkeit",
                        placeholder: "Deutschland",
                        icon: "flag.fill",
                        text: self.$nationality
                    )

                    LabeledInputField(
                        label: "Steuernummer",
                        placeholder: "Steuernummer eingeben",
                        icon: "doc.text.fill",
                        text: self.$taxNumber
                    )
                }

                // Additional fields (shown when + button is pressed)
                if self.showAdditionalFields {
                    VStack(spacing: ResponsiveDesign.spacing(16)) {
                        LabeledInputField(
                            label: "Zusätzlicher steuerlicher Wohnsitz",
                            placeholder: "Zusätzliches Land eingeben",
                            icon: "building.2.crossed.fill",
                            text: self.$additionalResidenceCountry
                        )

                        LabeledInputField(
                            label: "Zusätzliche Steuernummer",
                            placeholder: "Zusätzliche Steuernummer eingeben",
                            icon: "doc.text.2.crossed.fill",
                            text: self.$additionalTaxNumber
                        )
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Single unified + button
                Button(action: { self.showAdditionalFields.toggle() }, label: {
                    HStack {
                        Image(systemName: self.showAdditionalFields ? "minus.circle" : "plus.circle")
                            .foregroundColor(AppTheme.accentLightBlue)
                        Text(
                            self.showAdditionalFields ? "Zusätzliche Felder ausblenden" : "Zusätzlichen steuerlichen Wohnsitz & Steuernummer hinzufügen"
                        )
                        .foregroundColor(AppTheme.accentLightBlue)
                    }
                    .font(ResponsiveDesign.bodyFont())
                })
                .buttonStyle(PlainButtonStyle())
            }
            .responsivePadding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(16))
        }
        .animation(.easeInOut(duration: 0.3), value: self.showAdditionalFields)
    }
}

#Preview {
    CitizenshipTaxStep(
        isNotUSCitizen: .constant(true),
        nationality: .constant("Deutschland"),
        taxNumber: .constant("12345678901"),
        additionalResidenceCountry: .constant(""),
        additionalTaxNumber: .constant(""),
        address: .constant(""),
        showAdditionalFields: .constant(false)
    )
    .background(AppTheme.screenBackground)
}
