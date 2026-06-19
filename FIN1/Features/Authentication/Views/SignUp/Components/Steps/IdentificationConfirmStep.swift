import SwiftUI

// Import UI components
// Note: These components are now in the UI subfolder

struct IdentificationConfirmStep: View {
    let identificationType: IdentificationType
    let passportFrontImage: UIImage?
    let passportBackImage: UIImage?
    let idCardFrontImage: UIImage?
    let idCardBackImage: UIImage?
    @Binding var identificationConfirmed: Bool

    var body: some View {
        SignUpStepList {
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: "checkmark.circle.fill")
                    .font(ResponsiveDesign.scaledSystemFont(size: 60))
                    .foregroundColor(AppTheme.accentGreen)

                Text("Dokumente erfolgreich hochgeladen")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Bitte überprüfen Sie kurz Ihre Dokumente")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .signUpListSection(stripeIndex: 0)

            HStack(spacing: ResponsiveDesign.spacing(12)) {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    Text("Vorderseite")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)

                    if let frontImage = identificationType == .passport ? passportFrontImage : idCardFrontImage {
                        Image(uiImage: frontImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 120)
                            .cornerRadius(ResponsiveDesign.spacing(8))
                            .overlay(
                                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                                    .stroke(AppTheme.accentGreen, lineWidth: 2)
                            )
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    Text("Rückseite")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)

                    if let backImage = identificationType == .passport ? passportBackImage : idCardBackImage {
                        Image(uiImage: backImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 120)
                            .cornerRadius(ResponsiveDesign.spacing(8))
                            .overlay(
                                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                                    .stroke(AppTheme.accentGreen, lineWidth: 2)
                            )
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .signUpListSection(stripeIndex: 1)

            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Text("Qualitätsprüfung")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: ResponsiveDesign.spacing(12)) {
                    QualityCheckItem(
                        text: "Dokumente sind vollständig sichtbar",
                        isChecked: true
                    )
                    QualityCheckItem(
                        text: "Alle Ecken sind erkennbar",
                        isChecked: true
                    )
                    QualityCheckItem(
                        text: "Text ist gut lesbar",
                        isChecked: true
                    )
                    QualityCheckItem(
                        text: "Keine Reflexionen oder Schatten",
                        isChecked: true
                    )
                }
            }
            .signUpListSection(stripeIndex: 2)

            Button(action: { self.identificationConfirmed.toggle() }, label: {
                HStack {
                    InteractiveElement(
                        isSelected: self.identificationConfirmed,
                        type: .confirmationCircle
                    )

                    Text("Dokumente sind korrekt - Weiter")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)

                    Spacer()

                    if self.identificationConfirmed {
                        Image(systemName: "arrow.right")
                            .foregroundColor(AppTheme.accentGreen)
                            .font(ResponsiveDesign.headlineFont())
                    }
                }
            })
            .buttonStyle(PlainButtonStyle())
            .signUpListSection(
                stripeIndex: 3,
                isSelected: self.identificationConfirmed,
                selectionAccent: AppTheme.accentGreen
            )
        }
    }
}

// MARK: - Quality Check Item Component
struct QualityCheckItem: View {
    let text: String
    let isChecked: Bool

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: self.isChecked ? "checkmark.circle.fill" : "circle")
                .foregroundColor(self.isChecked ? AppTheme.accentGreen : AppTheme.fontColor.opacity(0.3))
                .font(ResponsiveDesign.headlineFont())

            Text(self.text)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)

            Spacer()
        }
    }
}

#Preview {
    IdentificationConfirmStep(
        identificationType: .passport,
        passportFrontImage: nil,
        passportBackImage: nil,
        idCardFrontImage: nil,
        idCardBackImage: nil,
        identificationConfirmed: .constant(false)
    )
    .background(AppTheme.screenBackground)
}
