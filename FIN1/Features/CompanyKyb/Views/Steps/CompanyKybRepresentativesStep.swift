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
                isOn: $formData.appAccountHolderIsRepresentative
            )

            ForEach(formData.representatives.indices, id: \.self) { index in
                representativeCard(index: index)
            }

            Button(action: addRepresentative) {
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
                if formData.representatives.count > 1 {
                    Button(action: { removeRepresentative(at: index) }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            }

            LabeledInputField(
                label: "Vollständiger Name",
                placeholder: "Anna Vertreterin",
                icon: "person",
                text: $formData.representatives[index].fullName
            )

            LabeledInputField(
                label: "Position / Rolle",
                placeholder: "z. B. Geschäftsführer",
                icon: "briefcase",
                text: $formData.representatives[index].roleTitle
            )

            toggleRow(
                title: "Einzelvertretungsberechtigt",
                isOn: $formData.representatives[index].signingAuthority
            )
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.isCompactDevice() ? 12 : 16)
    }

    private func addRepresentative() {
        formData.representatives.append(RepresentativeEntry())
    }

    private func removeRepresentative(at index: Int) {
        guard formData.representatives.indices.contains(index) else { return }
        formData.representatives.remove(at: index)
    }
}
