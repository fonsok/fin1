import SwiftUI

struct CompanyKybOwnersStep: View {
    @Binding var formData: BeneficialOwnersFormData

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            stepHeader(
                title: "Wirtschaftlich Berechtigte",
                subtitle: "Personen mit mehr als 25 % Beteiligung (UBOs)"
            )

            toggleRow(
                title: "Kein UBO mit mehr als 25 % Beteiligung",
                isOn: $formData.noUboOver25Percent
            )

            if !formData.noUboOver25Percent {
                ForEach(formData.ubos.indices, id: \.self) { index in
                    uboCard(index: index)
                }

                Button(action: addUbo) {
                    Label("UBO hinzufügen", systemImage: "plus.circle")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }

    private func uboCard(index: Int) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text("UBO \(index + 1)")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                Spacer()
                if formData.ubos.count > 1 {
                    Button(action: { removeUbo(at: index) }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            }

            LabeledInputField(
                label: "Vollständiger Name",
                placeholder: "Max Mustermann",
                icon: "person",
                text: $formData.ubos[index].fullName
            )

            LabeledInputField(
                label: "Geburtsdatum (JJJJ-MM-TT)",
                placeholder: "1980-01-15",
                icon: "calendar",
                text: $formData.ubos[index].dateOfBirth
            )

            LabeledInputField(
                label: "Staatsangehörigkeit",
                placeholder: "DE",
                icon: "globe",
                text: $formData.ubos[index].nationality,
                maxLength: 60
            )
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.isCompactDevice() ? 12 : 16)
    }

    private func addUbo() {
        formData.ubos.append(BeneficialOwnerEntry())
    }

    private func removeUbo(at index: Int) {
        guard formData.ubos.indices.contains(index) else { return }
        formData.ubos.remove(at: index)
    }
}
