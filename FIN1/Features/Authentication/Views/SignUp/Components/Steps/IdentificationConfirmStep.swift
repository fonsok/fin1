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
        VStack(spacing: ResponsiveDesign.spacing(24)) {
            // Success Header
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.accentGreen)

                Text("Dokumente erfolgreich hochgeladen")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
                    .multilineTextAlignment(.center)

                Text("Bitte überprüfen Sie kurz Ihre Dokumente")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            // Document Preview - Side by Side
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                // Front Side
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

                // Back Side
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
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(16))

            // Quality Check List
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
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(16))

            // Confirmation Button
            Button(action: { identificationConfirmed.toggle() }, label: {
                HStack {
                    InteractiveElement(
                        isSelected: identificationConfirmed,
                        type: .confirmationCircle
                    )

                    Text("Dokumente sind korrekt - Weiter")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)

                    Spacer()

                    if identificationConfirmed {
                        Image(systemName: "arrow.right")
                            .foregroundColor(AppTheme.accentGreen)
                            .font(ResponsiveDesign.headlineFont())
                    }
                }
                .padding()
                .background(identificationConfirmed ? AppTheme.accentGreen.opacity(0.1) : AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(12))
                .overlay(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                        .stroke(identificationConfirmed ? AppTheme.accentGreen : Color.clear, lineWidth: 2)
                )
            })
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Quality Check Item Component
struct QualityCheckItem: View {
    let text: String
    let isChecked: Bool

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isChecked ? AppTheme.accentGreen : AppTheme.fontColor.opacity(0.3))
                .font(ResponsiveDesign.headlineFont())

            Text(text)
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
