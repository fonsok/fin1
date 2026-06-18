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
        SignUpStepList {
            Text("Staatsbürgerschaft - Steuer")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .signUpListSection(stripeIndex: 0)

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
            .signUpListSection(
                stripeIndex: 1,
                isSelected: self.isNotUSCitizen,
                selectionAccent: AppTheme.accentGreen
            )

            VStack(spacing: ResponsiveDesign.spacing(20)) {
                Text("Staatsangehörigkeit & Steuer")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

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

                Button(action: { self.showAdditionalFields.toggle() }, label: {
                    HStack {
                        Image(systemName: self.showAdditionalFields ? "minus.circle" : "plus.circle")
                            .foregroundColor(AppTheme.accentLightBlue)
                        Text(
                            self.showAdditionalFields
                                ? "Zusätzliche Felder ausblenden"
                                : "Zusätzlichen steuerlichen Wohnsitz & Steuernummer hinzufügen"
                        )
                        .foregroundColor(AppTheme.accentLightBlue)
                    }
                    .font(ResponsiveDesign.bodyFont())
                })
                .buttonStyle(PlainButtonStyle())
            }
            .signUpListSection(stripeIndex: 2)
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
