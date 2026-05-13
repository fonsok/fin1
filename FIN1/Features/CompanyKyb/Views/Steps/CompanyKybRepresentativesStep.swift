import SwiftUI

struct CompanyKybRepresentativesStep: View {
    @Binding var formData: AuthorizedRepresentativesFormData

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            stepHeader(
                title: "Vertretungsberechtigte",
                subtitle: "Personen, die das Unternehmen vertreten dürfen"
            )

            toggleRow(
                title: "Der Kontoinhaber ist vertretungsberechtigt",
                isOn: self.$formData.appAccountHolderIsRepresentative
            )

            ForEach(self.formData.representatives.indices, id: \.self) { index in
                self.representativeCard(index: index)
            }

            Button(action: self.addRepresentative) {
                Label("Vertreter hinzufügen", systemImage: "plus.circle")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.accentLightBlue)
            }
        }
    }

    private func representativeCard(index: Int) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text("Vertreter \(index + 1)")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                Spacer()
                if self.formData.representatives.count > 1 {
                    Button(action: { self.removeRepresentative(at: index) }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            }

            LabeledInputField(
                label: "Vollständiger Name",
                placeholder: "Anna Vertreterin",
                icon: "person",
                text: self.$formData.representatives[index].fullName
            )

            LabeledInputField(
                label: "Position / Rolle",
                placeholder: "z. B. Geschäftsführer",
                icon: "briefcase",
                text: self.$formData.representatives[index].roleTitle
            )

            toggleRow(
                title: "Einzelvertretungsberechtigt",
                isOn: self.$formData.representatives[index].signingAuthority
            )
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.isCompactDevice() ? 12 : 16)
    }

    private func addRepresentative() {
        self.formData.representatives.append(RepresentativeEntry())
    }

    private func removeRepresentative(at index: Int) {
        guard self.formData.representatives.indices.contains(index) else { return }
        self.formData.representatives.remove(at: index)
    }
}
