import SwiftUI

// Import UI components
// Note: These components are now in the UI subfolder

struct IdentificationTypeStep: View {
    @Binding var identificationType: IdentificationType

    var body: some View {
        SignUpStepList {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Text("Identifikation")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)

                Text("Bitte wählen Sie Ihr Ausweisdokument aus")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
            }
            .signUpListSection(stripeIndex: 0)

            self.identificationOption(
                type: .passport,
                title: "Reisepass",
                subtitle: "Deutscher oder ausländischer Reisepass",
                stripeIndex: 1
            )

            self.identificationOption(
                type: .idCard,
                title: "Personalausweis",
                subtitle: "Deutscher Personalausweis",
                stripeIndex: 2
            )

            self.identificationOption(
                type: .postident,
                title: "Postident",
                subtitle: "Identifikation über Postident",
                stripeIndex: 3
            )

            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Text("Bitte bereiten Sie folgende Dokumente vor:")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    InfoBullet(text: "Dokument muss vollständig sichtbar sein")
                    InfoBullet(text: "Alle Ecken müssen erkennbar sein")
                    InfoBullet(text: "Dokument darf nicht abgeschnitten werden")
                    InfoBullet(text: "Bildqualität muss gut lesbar sein")
                }
            }
            .signUpListSection(stripeIndex: 4)
        }
    }

    private func identificationOption(
        type: IdentificationType,
        title: String,
        subtitle: String,
        stripeIndex: Int
    ) -> some View {
        Button(action: { self.identificationType = type }, label: {
            HStack(alignment: .top, spacing: ResponsiveDesign.spacing(12)) {
                InteractiveElement(
                    isSelected: self.identificationType == type,
                    type: .radioButton,
                    color: AppTheme.accentLightBlue
                )

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text(title)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)

                    Text(subtitle)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }

                Spacer(minLength: 0)
            }
        })
        .buttonStyle(PlainButtonStyle())
        .signUpListSection(
            stripeIndex: stripeIndex,
            isSelected: self.identificationType == type
        )
    }
}

#Preview {
    IdentificationTypeStep(identificationType: .constant(.passport))
        .background(AppTheme.screenBackground)
}
