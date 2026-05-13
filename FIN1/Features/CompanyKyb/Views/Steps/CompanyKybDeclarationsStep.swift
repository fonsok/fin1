import SwiftUI

struct CompanyKybDeclarationsStep: View {
    @Binding var formData: DeclarationsFormData

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            stepHeader(
                title: "Erklärungen",
                subtitle: "Gesetzlich vorgeschriebene Selbstauskünfte"
            )

            toggleRow(
                title: "Die Gesellschaft oder ein wirtschaftlich Berechtigter ist eine politisch exponierte Person (PEP).",
                isOn: self.$formData.isPoliticallyExposed
            )

            if self.formData.isPoliticallyExposed {
                LabeledInputField(
                    label: "PEP-Details",
                    placeholder: "Bitte erläutern…",
                    icon: "person.badge.shield.checkmark",
                    text: self.$formData.pepDetails
                )
            }

            self.declarationToggle(
                title: "Die Gesellschaft unterliegt keinen Sanktionen und ist auf keiner Sanktionsliste geführt.",
                isOn: self.$formData.sanctionsSelfDeclarationAccepted
            )

            self.declarationToggle(
                title: "Alle Angaben in diesem Antrag sind wahrheitsgemäß und vollständig.",
                isOn: self.$formData.accuracyDeclarationAccepted
            )

            self.declarationToggle(
                title: "Die Gesellschaft handelt im eigenen Namen und nicht als Treuhänder für Dritte.",
                isOn: self.$formData.noTrustThirdPartyDeclarationAccepted
            )
        }
    }

    private func declarationToggle(title: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: ResponsiveDesign.spacing(12)) {
            Button(action: { isOn.wrappedValue.toggle() }) {
                InteractiveElement(
                    isSelected: isOn.wrappedValue,
                    type: .checkbox,
                    color: AppTheme.accentLightBlue
                )
            }
            .buttonStyle(PlainButtonStyle())

            Text(title)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.isCompactDevice() ? 12 : 16)
    }
}
