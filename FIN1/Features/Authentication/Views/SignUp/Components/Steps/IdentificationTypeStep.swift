import SwiftUI

// Import UI components
// Note: These components are now in the UI subfolder

struct IdentificationTypeStep: View {
    @Binding var identificationType: IdentificationType

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(24)) {
            Text("Identifikation")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
                .multilineTextAlignment(.center)

            Text("Bitte wählen Sie Ihr Ausweisdokument aus")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .multilineTextAlignment(.leading)

            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Button(action: { self.identificationType = .passport }, label: {
                    HStack {
                        InteractiveElement(
                            isSelected: self.identificationType == .passport,
                            type: .radioButton,
                            color: AppTheme.accentLightBlue
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reisepass")
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.fontColor)

                            Text("Deutscher oder ausländischer Reisepass")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        }

                        Spacer()
                    }
                    .padding()
                    .background(self.identificationType == .passport ? AppTheme.accentLightBlue.opacity(0.1) : AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(12))
                    .overlay(
                        RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                            .stroke(self.identificationType == .passport ? AppTheme.accentLightBlue : Color.clear, lineWidth: 2)
                    )
                })
                .buttonStyle(PlainButtonStyle())

                Button(action: { self.identificationType = .idCard }, label: {
                    HStack {
                        InteractiveElement(
                            isSelected: self.identificationType == .idCard,
                            type: .radioButton,
                            color: AppTheme.accentLightBlue
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Personalausweis")
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.fontColor)

                            Text("Deutscher Personalausweis")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        }

                        Spacer()
                    }
                    .padding()
                    .background(self.identificationType == .idCard ? AppTheme.accentLightBlue.opacity(0.1) : AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(12))
                    .overlay(
                        RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                            .stroke(self.identificationType == .idCard ? AppTheme.accentLightBlue : Color.clear, lineWidth: 2)
                    )
                })
                .buttonStyle(PlainButtonStyle())

                Button(action: { self.identificationType = .postident }, label: {
                    HStack {
                        InteractiveElement(
                            isSelected: self.identificationType == .postident,
                            type: .radioButton,
                            color: AppTheme.accentLightBlue
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Postident")
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.fontColor)

                            Text("Identifikation über Postident")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        }

                        Spacer()
                    }
                    .padding()
                    .background(self.identificationType == .postident ? AppTheme.accentLightBlue.opacity(0.1) : AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(12))
                    .overlay(
                        RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                            .stroke(self.identificationType == .postident ? AppTheme.accentLightBlue : Color.clear, lineWidth: 2)
                    )
                })
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(16))

            // Instructions
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Text("Bitte bereiten Sie folgende Dokumente vor:")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    InfoBullet(text: "Dokument muss vollständig sichtbar sein")
                    InfoBullet(text: "Alle Ecken müssen erkennbar sein")
                    InfoBullet(text: "Dokument darf nicht abgeschnitten werden")
                    InfoBullet(text: "Bildqualität muss gut lesbar sein")
                }
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(16))
        }
    }
}

#Preview {
    IdentificationTypeStep(identificationType: .constant(.passport))
        .background(AppTheme.screenBackground)
}
