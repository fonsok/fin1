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
                isOn: self.$formData.noUboOver25Percent
            )

            if !self.formData.noUboOver25Percent {
                ForEach(self.formData.ubos.indices, id: \.self) { index in
                    self.uboCard(index: index)
                }

                Button(action: self.addUbo) {
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
                if self.formData.ubos.count > 1 {
                    Button(action: { self.removeUbo(at: index) }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            }

            LabeledInputField(
                label: "Vollständiger Name",
                placeholder: "Max Mustermann",
                icon: "person",
                text: self.$formData.ubos[index].fullName
            )

            LabeledInputField(
                label: "Geburtsdatum (JJJJ-MM-TT)",
                placeholder: "1980-01-15",
                icon: "calendar",
                text: self.$formData.ubos[index].dateOfBirth
            )

            LabeledInputField(
                label: "Staatsangehörigkeit",
                placeholder: "DE",
                icon: "globe",
                text: self.$formData.ubos[index].nationality,
                maxLength: 60
            )
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.isCompactDevice() ? 12 : 16)
    }

    private func addUbo() {
        self.formData.ubos.append(BeneficialOwnerEntry())
    }

    private func removeUbo(at index: Int) {
        guard self.formData.ubos.indices.contains(index) else { return }
        self.formData.ubos.remove(at: index)
    }
}
