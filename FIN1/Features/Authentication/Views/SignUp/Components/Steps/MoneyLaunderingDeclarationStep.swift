import SwiftUI

// Import UI components
// Note: These components are now in the UI subfolder

struct MoneyLaunderingDeclarationStep: View {
    @Binding var moneyLaunderingDeclaration: Bool
    @Binding var assetType: AssetType
    @State private var showBusinessAssetsNotification: Bool = false

    var body: some View {
        SignUpStepList {
            Text("Erklärungen")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .signUpListSection(stripeIndex: 0)

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(20)) {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                    Text("a) nach § 10 Absatz 1 Nummer 2 Geldwäschegesetz")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    Button(action: { self.moneyLaunderingDeclaration.toggle() }, label: {
                        HStack {
                            InteractiveElement(
                                isSelected: self.moneyLaunderingDeclaration,
                                type: .checkbox
                            )

                            Text("Ich handle/Wir handeln auf eigene Rechnung")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor)
                                .multilineTextAlignment(.leading)

                            Spacer()
                        }
                    })
                    .buttonStyle(PlainButtonStyle())
                }

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                    Text("b) nach § 43 Absatz 2 Satz 3 Nummer 2 EStG")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    Text("Bei den Vermögenswerten, die in dem beantragten Depot/Konto verwahrt werden sollen, handelt es sich um")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                        .multilineTextAlignment(.leading)

                    VStack(spacing: ResponsiveDesign.spacing(8)) {
                        Button(action: { self.assetType = .privateAssets }, label: {
                            HStack {
                                InteractiveElement(
                                    isSelected: self.assetType == .privateAssets,
                                    type: .radioButton
                                )

                                Text("Privatvermögen")
                                    .font(ResponsiveDesign.bodyFont())
                                    .foregroundColor(AppTheme.fontColor)

                                Spacer()
                            }
                        })
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            self.assetType = .businessAssets
                            self.showBusinessAssetsNotification = true
                        }) {
                            HStack {
                                InteractiveElement(
                                    isSelected: self.assetType == .businessAssets,
                                    type: .radioButton
                                )

                                Text("Betriebsvermögen")
                                    .font(ResponsiveDesign.bodyFont())
                                    .foregroundColor(AppTheme.fontColor)

                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .signUpListSection(stripeIndex: 1)

            Text("Mit klicken auf \"weiter\", erklären Sie sich mit den Bedingungen der oben genannten Dokumente einverstanden.")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .multilineTextAlignment(.leading)
                .signUpListSection(stripeIndex: 2)
        }
        .alert("Only Privatvermögen allowed", isPresented: self.$showBusinessAssetsNotification) {
            Button("OK") {
                self.showBusinessAssetsNotification = false
            }
        } message: {
            Text("Business assets are not currently supported. Please select 'Privatvermögen' to continue.")
        }
    }
}

#Preview {
    MoneyLaunderingDeclarationStep(
        moneyLaunderingDeclaration: .constant(false),
        assetType: .constant(.privateAssets)
    )
    .background(AppTheme.screenBackground)
}
